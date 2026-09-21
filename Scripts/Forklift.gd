extends VehicleBody3D
class_name ForkliftVehicle

signal pallet_picked_up(pallet: Node3D)
signal pallet_released(pallet: Node3D)
signal fork_height_changed(height: float)

@onready var wheel_fl: VehicleWheel3D = $Wheel_FL
@onready var wheel_fr: VehicleWheel3D = $Wheel_FR
@onready var drive_location: Node3D = $DriveLocation
@onready var exit_location: Node3D = $ExitLocation
@onready var fork: Node3D = $Body/Mast/Fork
@onready var mast: Node3D = $Body/Mast
@onready var steer_mesh: Node3D = $Body/Steer
@onready var lever_height: Node3D = $"Body/Lever-Height"
@onready var lever_tilt: Node3D = $"Body/Lever-Tilt"
@onready var fps_camera: Camera3D = $FPSCamera
@onready var engine_sfx: AudioStreamPlayer3D = $EngineSFX
@onready var lift_sfx: AudioStreamPlayer3D = $LiftSFX
@onready var reverse_beeper_sfx: AudioStreamPlayer3D = get_node_or_null("ReverseBeeperSFX")
@onready var horn_sfx: AudioStreamPlayer3D = get_node_or_null("HornSFX")
@onready var carry_point: Area3D = get_node_or_null("Body/Mast/Fork/CarryPoint")

# Realistic Industrial Forklift Physics Specs (2.5-ton warehouse truck)
var base_mass: float = 1600.0
var base_center_of_mass: Vector3 = Vector3(0.0, 0.15, 0.05) # Centered stably between front and rear axles

var max_rpm: float = 280.0
var max_torque: float = 900.0 ## Balanced torque for 1.6-ton machine to reach warehouse safe speeds (~10-12 km/h)
var engine_brake_strength: float = 30.0 ## Hydrostatic engine braking when throttle released

var is_controllable: bool = false
var lever_height_input: float = 0.0
var lever_tilt_input: float = 0.0

var min_velocity_length: float = 0.0
var max_velocity_length: float = 5.0

# Pallet Attachment & Cargo Weight Tracking
var nearby_pallets: Array[PalletCargo] = []
var carried_pallet: PalletCargo = null


func _ready() -> void:
	add_to_group("forklift")
	# Configure base physics parameters
	mass = base_mass
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = base_center_of_mass

	if lift_sfx:
		lift_sfx.stream_paused = true

	# Connect CarryPoint triggers if present
	if carry_point:
		carry_point.area_entered.connect(_on_carry_point_area_entered)
		carry_point.area_exited.connect(_on_carry_point_area_exited)

	fork.position.y = -0.230
	mast.rotation.x = deg_to_rad(1.8)



func _physics_process(delta: float) -> void:
	_handle_engine_sfx()

	# Process lift and dynamic cargo lock regardless of driving state
	_handle_lift_control(delta)
	_handle_cargo_weight_dynamics()

	if not is_controllable:
		# Engage parking brake when driver is not in the cab
		brake = 60.0
		wheel_fl.engine_force = 0.0
		wheel_fr.engine_force = 0.0
		if reverse_beeper_sfx and reverse_beeper_sfx.playing:
			reverse_beeper_sfx.stop()
		return

	# Rear-wheel steering simulation
	var steer_target: float = Input.get_axis("Steer Left", "Steer Right") * 0.55
	steering = lerp(steering, steer_target, 5.0 * delta)

	# Acceleration, Torque, and Hydrostatic Engine Braking
	var acceleration: float = Input.get_axis("Brake", "Throttle")
	if absf(acceleration) > 0.05:
		brake = 0.0
		var rpm: float = wheel_fl.get_rpm()
		wheel_fl.engine_force = acceleration * max_torque * (1.0 - rpm / max_rpm)
		rpm = wheel_fr.get_rpm()
		wheel_fr.engine_force = acceleration * max_torque * (1.0 - rpm / max_rpm)
	else:
		# Automatic hydrostatic engine brake when releasing pedal (prevents runaway roll)
		wheel_fl.engine_force = 0.0
		wheel_fr.engine_force = 0.0
		brake = engine_brake_strength

	_handle_reverse_beeper(acceleration)
	_handle_horn()
	_handle_steering_and_lever_animation(delta)



func _handle_lift_control(delta: float) -> void:
	var lift_action: bool = false

	if is_controllable:
		# Vertical Fork Translation
		if Input.is_action_pressed("Lift Up"):
			fork.position.y += 0.8 * delta
			lift_action = true
		if Input.is_action_pressed("Lift Down"):
			fork.position.y -= 0.8 * delta
			lift_action = true

		# Mast Forward/Back Tilt
		if Input.is_action_pressed("Lift Tilt Front"):
			mast.rotation.x += 0.25 * delta
			lift_action = true
		if Input.is_action_pressed("Lift Tilt Back"):
			mast.rotation.x -= 0.25 * delta
			lift_action = true

	fork.position.y = clampf(fork.position.y, -0.230, 1.878)
	mast.rotation.x = clampf(mast.rotation.x, deg_to_rad(-8.0), deg_to_rad(5.0))

	fork_height_changed.emit(fork.position.y)

	# Audio feedback for hydraulics
	if lift_sfx:
		if lift_action:
			lift_sfx.stream_paused = false
			if not lift_sfx.playing:
				lift_sfx.play()
		else:
			lift_sfx.stream_paused = true


## Manages real-life weight transfer, center-of-mass shift, and pallet pickup locking
func _handle_cargo_weight_dynamics() -> void:
	# 1. Attachment: Pick up pallet when forks lift off ground with pallet aligned and penetrated.
	#    Scan ALL pallets in the group – nearby_pallets can be stale after a drop because the
	#    pallet falls away from CarryPoint causing area_exited to clear the array.
	if carried_pallet == null and fork.position.y > -0.16:
		var tine_center: Vector3 = fork.to_global(Vector3(0.0, -0.16, 4.08))
		for p in get_tree().get_nodes_in_group("pallets"):
			if p is PalletCargo and is_instance_valid(p) and not p.is_carried:
				if p.is_aligned_with_forks(fork.global_transform):
					var horiz_dist: float = Vector2(
						p.global_position.x - tine_center.x,
						p.global_position.z - tine_center.z
					).length()
					# Pallet must be under the tine center (within 0.65 m horizontally)
					if horiz_dist <= 0.65:
						_attach_pallet(p)
						break

	# 2. Detachment: Release pallet when lowered flat to ground or placed on rack shelf
	elif carried_pallet != null and is_instance_valid(carried_pallet):
		var should_detach: bool = false
		if fork.position.y <= -0.21:
			# Fully lowered to ground level
			should_detach = true
		elif Input.is_action_pressed("Lift Down"):
			# Detect if pallet bottom has contacted an elevated shelf or floor while lowering
			var space_state = get_world_3d().direct_space_state
			var ray_from: Vector3 = carried_pallet.global_position + Vector3(0.0, 0.1, 0.0)
			var ray_to: Vector3 = carried_pallet.global_position + Vector3(0.0, -0.22, 0.0)
			var query = PhysicsRayQueryParameters3D.create(ray_from, ray_to)
			query.exclude = [get_rid(), carried_pallet.get_rid()]
			var result = space_state.intersect_ray(query)
			if result:
				should_detach = true

		if should_detach:
			_detach_pallet()

	# 3. Dynamic Center of Mass Adjustment while carrying load
	if carried_pallet != null and is_instance_valid(carried_pallet):
		var cargo_mass: float = carried_pallet.get_cargo_weight()
		var weight_ratio: float = cargo_mass / base_mass
		# Shift center of mass forward proportionally to load
		center_of_mass.z = base_center_of_mass.z + (weight_ratio * 0.35)
		# Raise center of mass higher as the mast elevates (creates realistic rollover risk in VR!)
		center_of_mass.y = base_center_of_mass.y + (fork.position.y + 0.2) * (weight_ratio * 0.4)


func _attach_pallet(pallet: PalletCargo) -> void:
	carried_pallet = pallet
	carried_pallet.set_carried(true)
	# Reparent to fork and seat flush on tines with zero gap
	carried_pallet.reparent(fork, false)
	carried_pallet.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, -0.16, 4.08))

	# Transfer cargo mass to vehicle
	mass = base_mass + carried_pallet.get_cargo_weight()
	pallet_picked_up.emit(carried_pallet)


func _detach_pallet() -> void:
	if carried_pallet and is_instance_valid(carried_pallet):
		var p = carried_pallet
		carried_pallet = null
		var current_global: Transform3D = p.global_transform
		p.reparent(get_tree().current_scene, false)
		p.global_transform = current_global
		p.set_carried(false)
		pallet_released.emit(p)

	# Restore unloaded forklift mass & center of mass
	mass = base_mass
	center_of_mass = base_center_of_mass


func _on_carry_point_area_entered(area: Area3D) -> void:
	var parent_body = area.get_parent()
	if parent_body is PalletCargo:
		if not nearby_pallets.has(parent_body):
			nearby_pallets.append(parent_body)


func _on_carry_point_area_exited(area: Area3D) -> void:
	var parent_body = area.get_parent()
	if parent_body is PalletCargo:
		nearby_pallets.erase(parent_body)


# Steering wheel and hydraulic lever visual animations
func _handle_steering_and_lever_animation(delta: float) -> void:
	if steer_mesh:
		steer_mesh.rotation.y = -steering * 2.5

	if lever_height:
		lever_height_input = lerp(lever_height_input, Input.get_axis("Lift Down", "Lift Up") * deg_to_rad(7.0), 5.0 * delta)
		lever_height.rotation.x = deg_to_rad(-14.8) + lever_height_input

	if lever_tilt:
		lever_tilt_input = lerp(lever_tilt_input, Input.get_axis("Lift Tilt Back", "Lift Tilt Front") * deg_to_rad(7.0), 5.0 * delta)
		lever_tilt.rotation.x = deg_to_rad(-14.8) + lever_tilt_input


# Dynamic engine audio pitch scaling
func _handle_engine_sfx() -> void:
	if not engine_sfx:
		return
	var velocity_length: float = clampf(linear_velocity.length(), 0.0, 5.0)
	var velocity_ratio: float = inverse_lerp(0.0, 5.0, velocity_length)
	engine_sfx.pitch_scale = 1.0 + (velocity_ratio * 0.4)


# Boarding trigger callbacks
func _on_boarding_area_body_entered(body: Node) -> void:
	if body.get_meta("is_player", false):
		body.add_available_vehicle(self)


func _on_boarding_area_body_exited(body: Node) -> void:
	if body.get_meta("is_player", false):
		body.remove_available_vehicle(self)


## Returns current fork elevation position (m)
func get_fork_height() -> float:
	return fork.position.y if fork else 0.0


## Returns live vehicle speed in km/h
func get_speed_kmh() -> float:
	return linear_velocity.length() * 3.6


## Returns whether forks are at or below OSHA safe transport height (<= 0.3m above ground)
func is_fork_at_travel_height() -> bool:
	return (fork.position.y if fork else 0.0) <= -0.05


## Returns transmission gear state ("F", "N", "R")
func get_gear_state() -> String:
	var forward_speed = linear_velocity.dot(global_transform.basis.z)
	if forward_speed < -0.15 or Input.is_action_pressed("Brake"):
		return "R"
	elif forward_speed > 0.15 or Input.is_action_pressed("Throttle"):
		return "F"
	return "N"


## Returns current forward/backward mast tilt in degrees
func get_mast_tilt_deg() -> float:
	return rad_to_deg(mast.rotation.x) if mast else 0.0


## Reverse safety beeper logic
func _handle_reverse_beeper(acceleration: float) -> void:
	if not reverse_beeper_sfx:
		return
	var is_reversing: bool = acceleration < -0.05 or linear_velocity.dot(global_transform.basis.z) < -0.2
	if is_reversing:
		if not reverse_beeper_sfx.playing:
			reverse_beeper_sfx.play()
	else:
		if reverse_beeper_sfx.playing:
			reverse_beeper_sfx.stop()


## Horn trigger logic
func _handle_horn() -> void:
	if not horn_sfx:
		return
	if Input.is_action_just_pressed("Horn"):
		horn_sfx.play()

