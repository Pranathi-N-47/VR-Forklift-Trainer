extends Node
class_name ViewpointController

## Seated Viewpoint & Cab Transition Controller
## Handles mounting/dismounting the forklift, seated camera anchoring,
## locomotion locking, input routing, and signaling state changes to TrainingManager.

signal seated_state_changed(is_seated: bool)
signal cab_proximity_changed(can_enter: bool, vehicle: Node3D)

@export var player: XRPlayer
@export var interaction_distance: float = 3.5
@export var driver_eye_height: float = 1.4
@export var player_cam_height: float = 1.65

var is_seated: bool = false
var current_vehicle: Node3D = null
var original_parent: Node = null
var nearby_vehicle: Node3D = null
var available_vehicles: Array[Node3D] = []

# Controller action names
const ACTION_USE: StringName = &"Use"


func _ready() -> void:
	if not player:
		if get_parent() is XRPlayer:
			player = get_parent() as XRPlayer


func _process(_delta: float) -> void:
	if not is_seated:
		_check_cab_proximity()
	_handle_input()


## Called by Forklift.gd BoardingArea trigger
func add_available_vehicle(vehicle: Node3D) -> void:
	if vehicle and not available_vehicles.has(vehicle):
		available_vehicles.append(vehicle)
		_update_proximity(available_vehicles[0])


## Called by Forklift.gd BoardingArea trigger
func remove_available_vehicle(vehicle: Node3D) -> void:
	available_vehicles.erase(vehicle)
	if available_vehicles.is_empty():
		_update_proximity(null)
	else:
		_update_proximity(available_vehicles[0])


func _check_cab_proximity() -> void:
	if not player:
		return

	# 1. If BoardingArea already detected a vehicle, use it
	if not available_vehicles.is_empty():
		var v = available_vehicles[0]
		if is_instance_valid(v):
			_update_proximity(v)
			return

	# 2. Distance-based fallback: check distance to any VehicleBody3D or "forklift" group
	var detected_vehicle: Node3D = null
	var vehicles = get_tree().get_nodes_in_group("forklift")

	if vehicles.is_empty():
		var tree_root = get_tree().current_scene
		if tree_root:
			vehicles = _find_nodes_of_type(tree_root, "VehicleBody3D")

	for v in vehicles:
		if not is_instance_valid(v):
			continue
		
		# Check distance to vehicle cab / drive location
		var check_pos: Vector3 = v.global_position
		var drive_loc = v.get_node_or_null("DriveLocation")
		if drive_loc:
			check_pos = drive_loc.global_position
		
		var dist = player.global_position.distance_to(check_pos)
		if dist <= interaction_distance:
			detected_vehicle = v
			break

	_update_proximity(detected_vehicle)


func _update_proximity(v: Node3D) -> void:
	if v != nearby_vehicle:
		nearby_vehicle = v
		cab_proximity_changed.emit(nearby_vehicle != null, nearby_vehicle)


func _handle_input() -> void:
	var use_pressed: bool = Input.is_action_just_pressed(ACTION_USE)

	# Also check VR Controller button triggers if active
	if not use_pressed and player and player.is_xr_active:
		if player.left_hand and player.left_hand.is_button_pressed("grip_click"):
			use_pressed = true
		elif player.right_hand and player.right_hand.is_button_pressed("grip_click"):
			use_pressed = true

	if use_pressed:
		if is_seated:
			exit_forklift()
		elif nearby_vehicle:
			enter_forklift(nearby_vehicle)


## Mounts the player inside the specified forklift cab
func enter_forklift(vehicle: Node3D) -> bool:
	if is_seated or not vehicle or not player:
		return false

	var seat_marker: Node3D = _get_seat_marker(vehicle)
	if not seat_marker:
		push_warning("ViewpointController: No SeatMarker3D or DriveLocation found on " + str(vehicle.name))
		return false

	current_vehicle = vehicle
	original_parent = player.get_parent()

	# 1. Disable player collision and character locomotion
	if player.collision_shape:
		player.collision_shape.disabled = true
	player.enable_locomotion(false)

	# 2. Calculate target eye position inside cab
	# In this forklift model, the mast and forks point along +Z of the vehicle.
	# The driver must face forward towards the forks (+Z relative to vehicle).
	var target_eye_pos: Vector3
	var target_rotation_y: float = vehicle.global_rotation.y + PI

	if seat_marker.name == "FPSCamera":
		target_eye_pos = seat_marker.global_position
	elif seat_marker.name == "SeatMarker3D":
		target_eye_pos = seat_marker.global_position
	else:
		# DriveLocation is at cab floor level (y ~ 0.0), so raise to eye level ~1.4m
		target_eye_pos = seat_marker.global_position + vehicle.global_transform.basis.y * driver_eye_height

	# 3. Reparent player to vehicle and position so camera is exactly at target_eye_pos
	player.reparent(vehicle, true)
	player.global_position = target_eye_pos - Vector3(0, player_cam_height, 0)
	player.global_rotation = Vector3(0, target_rotation_y, 0)

	# Reset camera pitch and local transforms so view looks level through front windshield
	player._cam_pitch = 0.0
	if player.xr_camera:
		player.xr_camera.rotation = Vector3.ZERO

	var xr_origin = player.get_xr_origin()
	if xr_origin:
		xr_origin.position = Vector3.ZERO
		xr_origin.rotation = Vector3.ZERO

	# 4. Route controls to the forklift
	_set_vehicle_controllable(current_vehicle, true)

	is_seated = true
	nearby_vehicle = null
	seated_state_changed.emit(true)
	return true


## Dismounts the player from the forklift cab back to world ground
func exit_forklift() -> bool:
	if not is_seated or not current_vehicle or not player:
		return false

	var exit_marker: Node3D = _get_exit_marker(current_vehicle)
	var exit_pos: Vector3
	var exit_rot_y: float

	if exit_marker:
		exit_pos = exit_marker.global_position
		exit_rot_y = exit_marker.global_rotation.y
	else:
		# Fallback: place player 1.8m to the driver's side of forklift on ground
		exit_pos = current_vehicle.global_position + current_vehicle.global_transform.basis.x * 1.6
		exit_pos.y = maxf(current_vehicle.global_position.y, 0.05)
		exit_rot_y = current_vehicle.global_rotation.y + PI

	# 1. Disable vehicle driving controls
	_set_vehicle_controllable(current_vehicle, false)

	# 2. Reparent player back to original scene root
	if original_parent and is_instance_valid(original_parent):
		player.reparent(original_parent, true)
	else:
		player.reparent(get_tree().current_scene, true)

	player.global_position = exit_pos
	player.rotation.y = exit_rot_y

	# Reset XROrigin local position
	var xr_origin = player.get_xr_origin()
	if xr_origin:
		xr_origin.position = Vector3.ZERO
		xr_origin.rotation = Vector3.ZERO

	# 3. Restore player collision and walking locomotion
	if player.collision_shape:
		player.collision_shape.disabled = false
	player.velocity = Vector3.ZERO
	player.enable_locomotion(true)

	is_seated = false
	var exited_vehicle = current_vehicle
	current_vehicle = null
	seated_state_changed.emit(false)

	# Update proximity state after exit
	nearby_vehicle = exited_vehicle
	cab_proximity_changed.emit(true, nearby_vehicle)
	return true


# Helper: Finds seat marker node (supports Dev B refactor and base repo names)
func _get_seat_marker(vehicle: Node) -> Node3D:
	if vehicle.has_node("SeatMarker3D"):
		return vehicle.get_node("SeatMarker3D") as Node3D
	elif vehicle.has_node("FPSCamera"):
		return vehicle.get_node("FPSCamera") as Node3D
	elif vehicle.has_node("DriveLocation"):
		return vehicle.get_node("DriveLocation") as Node3D
	return null


# Helper: Finds exit marker node (supports Dev B refactor and base repo names)
func _get_exit_marker(vehicle: Node) -> Node3D:
	if vehicle.has_node("ExitMarker3D"):
		return vehicle.get_node("ExitMarker3D") as Node3D
	# Note: In base forklift, ExitLocation was behind vehicle, but driver door is on left side
	# If vehicle has a custom left ExitMarker3D, use it.
	return null


# Helper: Enables or disables vehicle driving controls
func _set_vehicle_controllable(vehicle: Node, controllable: bool) -> void:
	if vehicle.has_method("set_controllable"):
		vehicle.call("set_controllable", controllable)
	elif "is_controllable" in vehicle:
		vehicle.set("is_controllable", controllable)


# Helper: Traverses tree for nodes of a given type
func _find_nodes_of_type(root: Node, type_name: String) -> Array[Node3D]:
	var results: Array[Node3D] = []
	if root.is_class(type_name):
		results.append(root as Node3D)
	for child in root.get_children():
		results.append_array(_find_nodes_of_type(child, type_name))
	return results
