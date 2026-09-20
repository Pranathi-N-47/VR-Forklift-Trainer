extends CharacterBody3D
class_name XRPlayer

## First-Person VR Player Controller for VR Forklift Operator Training
## Supports OpenXR controllers (headset / XR Device Simulator) and seamless desktop fallback (WASD + Mouse/QE).

signal footstep_played(footstep_index: int)

@export_group("Locomotion")
@export var move_speed: float = 4.0
@export var snap_turn_angle_deg: float = 45.0
@export var snap_turn_cooldown: float = 0.3
@export var mouse_sensitivity: float = 0.002
@export var enable_desktop_fallback: bool = true

@export_group("Footstep Audio")
@export var step_distance: float = 1.6
@export var min_pitch: float = 0.9
@export var max_pitch: float = 1.1

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var xr_origin: XROrigin3D = $XROrigin3D
@onready var xr_camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var left_hand: XRController3D = $XROrigin3D/LeftHand
@onready var right_hand: XRController3D = $XROrigin3D/RightHand
@onready var footstep_player: AudioStreamPlayer3D = $FootstepAudio
@onready var viewpoint_controller: ViewpointController = $ViewpointController
@onready var prompt_label_3d: Label3D = $XROrigin3D/XRCamera3D/PromptLabel3D
@onready var prompt_label_2d: Label = $HUD/CenterContainer/PromptLabel2D

# State
var is_locomotion_enabled: bool = true
var is_xr_active: bool = false
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Snap turning state
var _snap_turn_timer: float = 0.0
var _last_right_stick_x: float = 0.0

# Footstep tracking
var _distance_traveled_since_step: float = 0.0
var _footstep_sounds: Array[AudioStream] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Desktop mouse-look rotation
var _cam_pitch: float = 0.0
var _is_mouse_captured: bool = false


func _ready() -> void:
	# Set metadata required by Forklift.gd's BoardingArea detection
	set_meta("is_player", true)

	_rng.randomize()
	_load_footstep_sounds()
	_check_xr_status()

	if xr_camera:
		xr_camera.make_current()

	if viewpoint_controller:
		viewpoint_controller.cab_proximity_changed.connect(_on_cab_proximity_changed)
		viewpoint_controller.seated_state_changed.connect(_on_seated_state_changed)

	_update_prompt("", false)

	if not is_xr_active and enable_desktop_fallback:
		# Start in desktop testing mode
		_capture_mouse()


## Interface required by Forklift.gd BoardingArea
func add_available_vehicle(vehicle: Node3D) -> void:
	if viewpoint_controller:
		viewpoint_controller.add_available_vehicle(vehicle)


## Interface required by Forklift.gd BoardingArea
func remove_available_vehicle(vehicle: Node3D) -> void:
	if viewpoint_controller:
		viewpoint_controller.remove_available_vehicle(vehicle)


func _on_cab_proximity_changed(can_enter: bool, _vehicle: Node3D) -> void:
	if viewpoint_controller and viewpoint_controller.is_seated:
		return
	if can_enter:
		_update_prompt("[E] or VR Trigger: Enter Forklift", true)
	else:
		_update_prompt("", false)


func _on_seated_state_changed(is_seated: bool) -> void:
	if is_seated:
		_update_prompt("[E]: Exit Forklift  |  [W/S]: Drive  [A/D]: Steer  [R/F]: Lift Forks  [H]: Horn", true)
	else:
		if viewpoint_controller and viewpoint_controller.nearby_vehicle:
			_update_prompt("[E] or VR Trigger: Enter Forklift", true)
		else:
			_update_prompt("", false)


func _update_prompt(text: String, is_visible: bool) -> void:
	if prompt_label_3d:
		prompt_label_3d.text = text
		prompt_label_3d.visible = is_visible
	if prompt_label_2d:
		prompt_label_2d.text = text
		prompt_label_2d.visible = is_visible


func _check_xr_status() -> void:
	var xr_interface: XRInterface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		is_xr_active = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		get_viewport().use_xr = true
	else:
		is_xr_active = false


func _load_footstep_sounds() -> void:
	_footstep_sounds.clear()
	for i in range(10):
		var sound_path: String = "res://Sounds/Footsteps/footstep%02d.ogg" % i
		if ResourceLoader.exists(sound_path):
			var stream = load(sound_path)
			if stream is AudioStream:
				_footstep_sounds.append(stream)


func _unhandled_input(event: InputEvent) -> void:
	# Mouse capture toggle for desktop debugging
	if event.is_action_pressed("Show Cursor"):
		if _is_mouse_captured:
			_release_mouse()
		else:
			_capture_mouse()

	# Desktop mouse look when not in VR
	if not is_xr_active and _is_mouse_captured and event is InputEventMouseMotion:
		_handle_mouse_look(event.relative)


func _capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_is_mouse_captured = true


func _release_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_is_mouse_captured = false


func _handle_mouse_look(relative: Vector2) -> void:
	# Rotate player body horizontally
	rotate_y(-relative.x * mouse_sensitivity)
	# Pitch camera vertically (clamped)
	_cam_pitch = clampf(_cam_pitch - relative.y * mouse_sensitivity, -deg_to_rad(85.0), deg_to_rad(85.0))
	xr_camera.rotation.x = _cam_pitch


func _physics_process(delta: float) -> void:
	# When seated in the cab, physics and gravity must be completely disabled
	if not is_locomotion_enabled:
		velocity = Vector3.ZERO
		return

	if _snap_turn_timer > 0.0:
		_snap_turn_timer -= delta

	# Apply gravity only when walking on foot
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle turning & locomotion
	_process_turning(delta)
	_process_locomotion(delta)

	var prev_pos = global_position
	move_and_slide()

	# Track distance walked on floor for footsteps
	if is_on_floor():
		var horizontal_delta = Vector2(global_position.x - prev_pos.x, global_position.z - prev_pos.z).length()
		_distance_traveled_since_step += horizontal_delta
		if _distance_traveled_since_step >= step_distance:
			_play_footstep()
			_distance_traveled_since_step = 0.0


func _process_turning(_delta: float) -> void:
	var turn_input: float = 0.0

	# 1. XR Controller thumbstick (Right Hand primary 2D axis X)
	if is_xr_active and right_hand:
		var right_vector = right_hand.get_vector2("primary")
		turn_input = right_vector.x

	# 2. Desktop fallback (Q / E keys)
	if is_zero_approx(turn_input):
		if Input.is_action_just_pressed("Turn Left"):
			rotate_y(deg_to_rad(snap_turn_angle_deg))
			return
		elif Input.is_action_just_pressed("Turn Right"):
			rotate_y(deg_to_rad(-snap_turn_angle_deg))
			return

	# VR Snap Turning with flick detection
	if absf(turn_input) > 0.5:
		if _snap_turn_timer <= 0.0 and absf(_last_right_stick_x) <= 0.5:
			var angle = deg_to_rad(-snap_turn_angle_deg) if turn_input > 0.0 else deg_to_rad(snap_turn_angle_deg)
			rotate_y(angle)
			_snap_turn_timer = snap_turn_cooldown
	_last_right_stick_x = turn_input


func _process_locomotion(_delta: float) -> void:
	var input_dir: Vector2 = Vector2.ZERO

	# 1. XR Left Controller thumbstick
	if is_xr_active and left_hand:
		var left_vector = left_hand.get_vector2("primary")
		input_dir.x = left_vector.x
		input_dir.y = -left_vector.y

	# 2. Desktop keyboard fallback (WASD)
	if input_dir.length_squared() < 0.01:
		input_dir = Input.get_vector("Move Left", "Move Right", "Move Down", "Move Up")

	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	# Determine heading: In VR orient with headset/camera heading, otherwise body basis
	var forward: Vector3 = -xr_camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right: Vector3 = xr_camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()

	var move_direction = (right * input_dir.x + forward * input_dir.y)

	velocity.x = move_direction.x * move_speed
	velocity.z = move_direction.z * move_speed


func _play_footstep() -> void:
	if _footstep_sounds.is_empty() or not footstep_player:
		return

	var random_index: int = _rng.randi_range(0, _footstep_sounds.size() - 1)
	footstep_player.stream = _footstep_sounds[random_index]
	footstep_player.pitch_scale = _rng.randf_range(min_pitch, max_pitch)
	footstep_player.play()
	footstep_played.emit(random_index)


## Enables or disables character locomotion (used when seated in cab)
func enable_locomotion(enable: bool) -> void:
	is_locomotion_enabled = enable
	if not enable:
		velocity = Vector3.ZERO


## Returns the active XR Camera
func get_camera() -> XRCamera3D:
	return xr_camera


## Returns the XROrigin3D node
func get_xr_origin() -> XROrigin3D:
	return xr_origin


## Returns whether the player is on floor
func is_walking_on_floor() -> bool:
	return is_on_floor() and is_locomotion_enabled and velocity.length_squared() > 0.1


## Teleports the player to a new location and orientation (used during training stage transitions)
func teleport_to(target_transform: Transform3D) -> void:
	if viewpoint_controller and viewpoint_controller.is_seated:
		viewpoint_controller.exit_forklift()
	velocity = Vector3.ZERO
	global_transform = target_transform
	_distance_traveled_since_step = 0.0
	_cam_pitch = 0.0
	if xr_camera:
		xr_camera.rotation.x = 0.0


## Teleports the player to a specific position and yaw angle
func teleport_to_position(pos: Vector3, yaw_rad: float = 0.0) -> void:
	if viewpoint_controller and viewpoint_controller.is_seated:
		viewpoint_controller.exit_forklift()
	velocity = Vector3.ZERO
	global_position = pos
	global_rotation = Vector3(0.0, yaw_rad, 0.0)
	_distance_traveled_since_step = 0.0
	_cam_pitch = 0.0
	if xr_camera:
		xr_camera.rotation.x = 0.0


