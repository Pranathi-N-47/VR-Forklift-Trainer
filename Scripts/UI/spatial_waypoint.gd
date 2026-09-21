extends Node3D
class_name SpatialWaypoint

## Dynamic 3D Spatial Waypoint & Screen-Edge Directional Guidance
## Displays a holographic in-world beacon at the active stage target.
## If the target moves outside the player's camera frustum, clamps an arrow
## to the screen edge so the trainee never gets lost in the simulator.

@export var training_manager: TrainingManager
@export var player: XRPlayer

# 3D In-World Beacon
@onready var beacon_mesh: MeshInstance3D = $BeaconPillar
@onready var beacon_ring: MeshInstance3D = $BeaconRing
@onready var label_3d: Label3D = $Label3D

# 2D Screen-Edge Clamped Indicator
@onready var edge_canvas: CanvasLayer = $EdgeCanvas
@onready var edge_indicator: Control = $EdgeCanvas/EdgeIndicator
@onready var arrow_icon: Label = $EdgeCanvas/EdgeIndicator/ArrowIcon
@onready var edge_label: Label = $EdgeCanvas/EdgeIndicator/EdgeLabel

var target_position: Vector3 = Vector3.ZERO
var target_name: String = ""
var is_waypoint_active: bool = false
var _anim_time: float = 0.0


func _ready() -> void:
	if not training_manager:
		var mgrs = get_tree().get_nodes_in_group("training_manager")
		if not mgrs.is_empty():
			training_manager = mgrs[0]

	if not player:
		player = get_tree().get_first_node_in_group("player") as XRPlayer

	if training_manager:
		training_manager.stage_changed.connect(_on_stage_changed)

	_update_target_for_stage(training_manager.current_stage if training_manager else 0)


func _process(delta: float) -> void:
	if not is_waypoint_active:
		visible = false
		if edge_indicator:
			edge_indicator.visible = false
		return

	visible = true
	_anim_time += delta * 2.5

	# Subtle floating bob and spin
	if beacon_ring:
		beacon_ring.position.y = 0.6 + sin(_anim_time) * 0.12
		beacon_ring.rotate_y(delta * 1.5)

	# Calculate distance
	var cam: Camera3D = _get_active_camera()
	if not cam:
		return

	var dist = cam.global_position.distance_to(target_position)
	if label_3d:
		label_3d.text = "%s\n[ %3.1fm ]" % [target_name, dist]

	_update_screen_edge_indicator(cam, dist)


func _get_active_camera() -> Camera3D:
	if player and player.xr_camera and player.xr_camera.current:
		return player.xr_camera
	return get_viewport().get_camera_3d()


func _update_screen_edge_indicator(cam: Camera3D, dist: float) -> void:
	if not edge_indicator or not cam:
		return

	var vp_size = get_viewport().get_visible_rect().size
	var is_behind = cam.is_position_behind(target_position)
	var screen_pos = cam.unproject_position(target_position)

	# Margin padding from screen borders
	var margin: float = 65.0
	var min_x = margin
	var max_x = vp_size.x - margin
	var min_y = margin
	var max_y = vp_size.y - margin

	var is_on_screen = not is_behind and screen_pos.x >= min_x and screen_pos.x <= max_x and screen_pos.y >= min_y and screen_pos.y <= max_y

	if is_on_screen:
		# Target is squarely in view, hide screen-edge pointer
		edge_indicator.visible = false
	else:
		edge_indicator.visible = true

		if is_behind:
			screen_pos = -screen_pos

		var screen_center = vp_size * 0.5
		var dir = (screen_pos - screen_center).normalized()

		# Clamp position to monitor rectangle border
		var clamped_x = clampf(screen_pos.x, min_x, max_x)
		var clamped_y = clampf(screen_pos.y, min_y, max_y)

		# If behind, push outward along direction vector
		if is_behind:
			var slope = dir.y / (dir.x if absf(dir.x) > 0.001 else 0.001)
			if absf(dir.x) * (vp_size.y * 0.5) > absf(dir.y) * (vp_size.x * 0.5):
				clamped_x = max_x if dir.x > 0 else min_x
				clamped_y = clampf(screen_center.y + (clamped_x - screen_center.x) * slope, min_y, max_y)
			else:
				clamped_y = max_y if dir.y > 0 else min_y
				clamped_x = clampf(screen_center.x + (clamped_y - screen_center.y) / slope, min_x, max_x)

		edge_indicator.position = Vector2(clamped_x, clamped_y)

		# Rotate arrow to point towards target
		var angle = dir.angle()
		if arrow_icon:
			arrow_icon.rotation = angle

		if edge_label:
			edge_label.text = "%s [ %dm ]" % [target_name, int(dist)]


func _on_stage_changed(stage: int, _stage_name: String) -> void:
	_update_target_for_stage(stage)


func _update_target_for_stage(stage: int) -> void:
	# Define target position for each stage
	match stage:
		0: # Inspection
			is_waypoint_active = true
			target_name = "Forklift Inspection Bay"
			target_position = Vector3(0, 0.2, 12.0)
		1: # Enter Cab
			is_waypoint_active = true
			target_name = "Mount Forklift Cab"
			target_position = Vector3(1.4, 0.5, 11.75)
		2: # Controls check
			is_waypoint_active = false
		3: # Slalom course
			is_waypoint_active = true
			target_name = "Slalom Course Entrance"
			target_position = Vector3(0, 0.2, 8.0)
		4: # Cargo mission / pickup
			is_waypoint_active = true
			target_name = "Pallet Staging Area (Pickup)"
			target_position = Vector3(0, 0.2, -13.5)
		5: # Transport to Drop Rack
			is_waypoint_active = true
			target_name = "Raised Dropoff Rack (1.2m)"
			target_position = Vector3(-16.0, 1.2, -14.0)
		6: # Parking Bay
			is_waypoint_active = true
			target_name = "Designated Parking Bay"
			target_position = Vector3(-16.0, 0.2, 12.0)
		_:
			is_waypoint_active = false

	global_position = target_position
