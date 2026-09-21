extends Node
class_name TrainingManager

## Master Training State Machine for VR Forklift Operator Training
## Coordinates the 7 structured training stages, provides stage-gated instructions,
## announces stage completions, enforces physical barriers, and tracks OSHA compliance.

signal stage_started(stage: int, stage_name: String, objective: String, tasks: String, completion_criteria: String)
signal stage_finished(previous_stage: int, stage_name: String)
signal stage_changed(new_stage: int, stage_name: String)
signal penalty_applied(reason: String, points: int, current_score: int)
signal training_completed(final_score: int, elapsed_time: float, cone_hits: int, total_penalties: int)

enum TrainingStage {
	STAGE_1_INSPECTION = 0,     # Pre-operation 4-point walkaround
	STAGE_2_ENTER_CAB = 1,      # Safe vehicle boarding
	STAGE_3_CONTROLS_CHECK = 2, # Test hydraulic mast lift & tilt
	STAGE_4_DRIVE_SLALOM = 3,   # Cone slalom driving course
	STAGE_5_CARGO_MISSION = 4,  # Ground Pickup -> Transport -> Raised Rack
	STAGE_6_PARK_FORKLIFT = 5,  # Park in bay, lower forks, shutdown
	STAGE_7_COMPLETED = 6       # Training report card & evaluation
}

const STAGE_NAMES: Array[String] = [
	"Stage 1: Pre-Operation Inspection",
	"Stage 2: Mount Forklift Cab",
	"Stage 3: Controls Familiarization (Mast Lift & Tilt)",
	"Stage 4: Driving Maneuver & Cone Slalom",
	"Stage 5: Cargo Transport Mission (Ground Pickup to Raised Rack)",
	"Stage 6: Parking Bay & Shutdown",
	"Stage 7: OSHA Certification & Evaluation"
]

const STAGE_OBJECTIVES: Array[String] = [
	"Perform an OSHA-standard physical walkaround check before starting the vehicle.",
	"Safe vehicle boarding.",
	"Test and verify hydraulic mast operation before driving.",
	"Maneuver the forklift with rear-wheel steering dynamics through a narrow driving course.",
	"Full pallet handling cycle under pure physics.",
	"Standard industrial parking and shutdown protocol.",
	"Training debriefing and scoring summary."
]

const STAGE_TASKS: Array[String] = [
	"Locate and inspect all 4 yellow inspection checkpoints around the forklift:\n• Front Mast & Forks\n• Tires & Lug Nuts\n• Rear Counterweight\n• Overhead Cab Guard",
	"Walk up to the driver's side door and mount the cab using [E] (or VR Controller Trigger).",
	"• Test vertical lift up/down ([R / F] on keyboard or Right VR Stick Y).\n• Test mast tilt forward/backward ([T / G] on keyboard or Right VR Stick X).",
	"Drive through the marked training slalom lane ([W/S] for throttle/braking, [A/D] or Left VR Stick for rear-wheel steering).\n\nOSHA Safety Rule: Avoid hitting or knocking over any traffic cones (-5 points penalty per knocked cone).",
	"1. Approach the ground pallet staging area.\n2. Align and slide tines completely through the pallet pockets.\n3. Tilt mast back slightly to cradle the load and lift off the ground.\n4. Transport cargo across the facility to the Drop Zone.\n5. Elevate forks to ~1.2 m and slide pallet squarely onto the raised warehouse rack shelf.\n6. Lower forks to release and back out cleanly.",
	"1. Drive the forklift into the designated Parking Bay.\n2. Lower the forks completely down to the ground.\n3. Dismount from the cab using [E] (or VR Trigger).",
	"Review your OSHA certification report card, score breakdown, and elapsed duration below.\n(Tip for testing: Pressing number keys 1 through 7 on your keyboard allows quick jumping between any of the stages at any time)."
]

const STAGE_COMPLETION: Array[String] = [
	"All 4 checkpoints inspected and cleared.",
	"Seated state active; player transitions into driving mode.",
	"Fork height tested; physical bay exit barrier opens.",
	"Clear the slalom lane and reach the Staging Area gate.",
	"Pallet safely placed and released on the elevated rack shelf.",
	"Vehicle parked, forks lowered, and driver safely exited the cab.",
	"Report card and evaluation generated."
]

const STAGE_MARKER_NAMES: Array[String] = [
	"Stage1_Inspection",
	"Stage2_CabEntry",
	"Stage3_Controls",
	"Stage4_Slalom",
	"Stage5_CargoMission",
	"Stage6_Parking",
	"Stage7_Complete"
]

@export var player: XRPlayer
@export var forklift: VehicleBody3D
@export var stage_markers_root: Node3D
@export var stage_barriers_root: Node3D
@export var guidance_display: Label3D
@export var score_display: Label3D
@export var checkpoints_container: Node3D

var current_stage: int = TrainingStage.STAGE_1_INSPECTION
var osha_score: int = 100
var elapsed_time: float = 0.0
var is_training_active: bool = true

# Tracking & Statistics
var cone_hits: int = 0
var total_penalties: int = 0
var _inspected_count: int = 0
var _total_checkpoints: int = 4

# Stage 3 Controls Test Tracking
var _lift_tested: bool = false
var _tilt_tested: bool = false
var _stage3_timer: float = 0.0
var _initial_fork_height: float = 0.0


func _ready() -> void:
	var root_win: Window = get_tree().root
	if root_win:
		root_win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root_win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		root_win.content_scale_size = Vector2i(1920, 1080)

	add_to_group("training_manager")
	if not player:
		player = get_tree().get_first_node_in_group("player") as XRPlayer
	if not forklift:
		forklift = get_tree().get_first_node_in_group("forklift") as VehicleBody3D

	_connect_traffic_cones()
	_connect_inspection_checkpoints()
	_connect_viewpoint_controller()
	_connect_forklift_events()

	start_stage(TrainingStage.STAGE_1_INSPECTION, true)


func _process(delta: float) -> void:
	if not is_training_active:
		return

	elapsed_time += delta
	_handle_debug_keys()
	_update_displays()

	# Process active stage conditions
	match current_stage:
		TrainingStage.STAGE_3_CONTROLS_CHECK:
			_process_stage_3_controls(delta)
		TrainingStage.STAGE_4_DRIVE_SLALOM:
			_process_stage_4_slalom()


func _handle_debug_keys() -> void:
	for key_idx in range(7):
		var action_key = KEY_1 + key_idx
		if Input.is_physical_key_pressed(action_key):
			if current_stage != key_idx:
				start_stage(key_idx, true)
				return


## Starts a specific stage, updates instructions, adjusts physical barriers, and teleports player
func start_stage(stage_index: int, teleport_player: bool = true) -> void:
	var prev_stage = current_stage
	current_stage = clampi(stage_index, 0, 6)

	# If changing from an earlier stage to the next, announce previous stage finished
	if current_stage > prev_stage and prev_stage < STAGE_NAMES.size():
		stage_finished.emit(prev_stage, STAGE_NAMES[prev_stage])

	# Update physical barriers
	_update_stage_barriers(current_stage)

	# Teleport player if requested
	if teleport_player and stage_markers_root and player:
		var marker = _get_stage_marker(current_stage)
		if marker:
			player.teleport_to(marker.global_transform)

	# Setup stage specific conditions
	match current_stage:
		TrainingStage.STAGE_1_INSPECTION:
			_inspected_count = 0
			_set_checkpoints_active(true)
		TrainingStage.STAGE_2_ENTER_CAB:
			_set_checkpoints_active(false)
		TrainingStage.STAGE_3_CONTROLS_CHECK:
			_lift_tested = false
			_tilt_tested = false
			_stage3_timer = 0.0
			if forklift and forklift.has_method("get_fork_height"):
				_initial_fork_height = forklift.get_fork_height()
			elif forklift and "fork" in forklift and forklift.fork:
				_initial_fork_height = forklift.fork.position.y
		TrainingStage.STAGE_4_DRIVE_SLALOM:
			_reset_traffic_cones()
			# Turn forklift so it faces directly toward the slalom cones (-Z direction)!
			_reset_forklift_transform(Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 0.25, 8.5)))
			_ensure_player_seated()
		TrainingStage.STAGE_5_CARGO_MISSION:
			_ensure_player_seated()
		TrainingStage.STAGE_6_PARK_FORKLIFT:
			_ensure_player_seated()
		TrainingStage.STAGE_7_COMPLETED:
			is_training_active = false
			training_completed.emit(osha_score, elapsed_time, cone_hits, total_penalties)

	# Emit stage started with full detailed instruction text
	stage_started.emit(
		current_stage,
		STAGE_NAMES[current_stage],
		STAGE_OBJECTIVES[current_stage],
		STAGE_TASKS[current_stage],
		STAGE_COMPLETION[current_stage]
	)
	stage_changed.emit(current_stage, STAGE_NAMES[current_stage])
	_update_displays()


func advance_to_next_stage() -> void:
	if current_stage < TrainingStage.STAGE_7_COMPLETED:
		# If the player is already seated in the cab (Stages 2 -> 3 -> 4 -> 5 -> 6),
		# keep them seated in the forklift instead of kicking them out!
		var should_teleport: bool = true
		if player and player.viewpoint_controller and player.viewpoint_controller.is_seated:
			should_teleport = false
		start_stage(current_stage + 1, should_teleport)


func apply_penalty(reason: String, points: int) -> void:
	osha_score = maxi(0, osha_score - points)
	total_penalties += points
	if "Cone" in reason or "cone" in reason:
		cone_hits += 1

	penalty_applied.emit(reason, points, osha_score)
	_update_displays()


## Updates physical barrier collisions so players cannot enter reserved areas of other stages
func _update_stage_barriers(stage_idx: int) -> void:
	if not stage_barriers_root:
		return

	# Barrier 1: Forklift Bay Exit Barrier
	var bay_barrier = stage_barriers_root.get_node_or_null("Barrier_ForkliftBay")
	if bay_barrier:
		var bay_closed = stage_idx < TrainingStage.STAGE_4_DRIVE_SLALOM
		_set_barrier_state(bay_barrier, bay_closed)

	# Barrier 2: Slalom Exit Gate
	var slalom_barrier = stage_barriers_root.get_node_or_null("Barrier_SlalomExit")
	if slalom_barrier:
		var slalom_closed = stage_idx < TrainingStage.STAGE_5_CARGO_MISSION
		_set_barrier_state(slalom_barrier, slalom_closed)

	# Barrier 3: Parking Bay Barrier
	var parking_barrier = stage_barriers_root.get_node_or_null("Barrier_ParkingBay")
	if parking_barrier:
		var parking_closed = stage_idx < TrainingStage.STAGE_6_PARK_FORKLIFT
		_set_barrier_state(parking_barrier, parking_closed)


func _set_barrier_state(barrier: Node, is_blocking: bool) -> void:
	if barrier is StaticBody3D:
		barrier.visible = is_blocking
		for child in barrier.get_children():
			if child is CollisionShape3D:
				child.disabled = not is_blocking
	elif barrier is Node3D:
		barrier.visible = is_blocking
		var col = barrier.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col:
			col.disabled = not is_blocking


func _get_stage_marker(stage_idx: int) -> Marker3D:
	if not stage_markers_root:
		return null
	var marker_name = STAGE_MARKER_NAMES[stage_idx]
	if stage_markers_root.has_node(marker_name):
		return stage_markers_root.get_node(marker_name) as Marker3D
	return null


# Stage 3: Controls Check progress
func _process_stage_3_controls(delta: float) -> void:
	# Detect keyboard / action inputs
	if Input.is_action_pressed("Lift Up") or Input.is_action_pressed("Lift Down"):
		_lift_tested = true
	if Input.is_action_pressed("Lift Tilt Front") or Input.is_action_pressed("Lift Tilt Back"):
		_tilt_tested = true

	# Detect physical movement from VR sticks or other controllers
	if forklift:
		var curr_h: float = forklift.get_fork_height() if forklift.has_method("get_fork_height") else (forklift.fork.position.y if "fork" in forklift and forklift.fork else 0.0)
		if absf(curr_h - _initial_fork_height) > 0.03:
			_lift_tested = true
		var curr_tilt: float = forklift.get_mast_tilt_deg() if forklift.has_method("get_mast_tilt_deg") else (rad_to_deg(forklift.mast.rotation.x) if "mast" in forklift and forklift.mast else 0.0)
		if absf(curr_tilt) > 0.5:
			_tilt_tested = true

	# Attempting to drive also confirms controls are understood
	if Input.is_action_pressed("Throttle") or Input.is_action_pressed("Brake"):
		_lift_tested = true

	# Completion Criteria: Fork height tested (or tilt tested)
	if _lift_tested or _tilt_tested:
		_stage3_timer += delta
		if _stage3_timer >= 0.5:
			advance_to_next_stage()


# Stage 4: Slalom completion check
func _process_stage_4_slalom() -> void:
	if not forklift:
		return
	# When the forklift navigates through cones and reaches Z <= -7.5 (the Staging gate)
	if forklift.global_position.z <= -7.5:
		advance_to_next_stage()


func _update_displays() -> void:
	if guidance_display:
		var title = STAGE_NAMES[current_stage]
		var obj = STAGE_OBJECTIVES[current_stage]
		var tasks = STAGE_TASKS[current_stage]
		if current_stage == TrainingStage.STAGE_3_CONTROLS_CHECK:
			var lift_status = "[CHECKED]" if _lift_tested else "[PRESS R / F]"
			var tilt_status = "[CHECKED]" if _tilt_tested else "[PRESS T / G]"
			tasks = "Hydraulics Checklist:\n• Fork Lift Up/Down: %s\n• Mast Tilt Front/Back: %s\n(Bay barrier opens automatically once tested)" % [lift_status, tilt_status]
		guidance_display.text = "=== %s ===\n\nOBJECTIVE: %s\n\nTASKS:\n%s" % [title, obj, tasks]

	if score_display:
		var mins = int(elapsed_time) / 60
		var secs = int(elapsed_time) % 60
		var grade = "PASS" if osha_score >= 70 else "FAIL"
		score_display.text = "OSHA Score: %d / 100 [%s]  Time: %02d:%02d\n(Quick Jump: Keys 1 - 7)" % [
			osha_score, grade, mins, secs
		]


# Connect signals from Traffic Cones
func _connect_traffic_cones() -> void:
	var cones = get_tree().get_nodes_in_group("traffic_cones")
	for cone in cones:
		if cone.has_signal("cone_knocked"):
			if not cone.cone_knocked.is_connected(_on_cone_knocked):
				cone.cone_knocked.connect(_on_cone_knocked)


func _on_cone_knocked(_cone: Node3D) -> void:
	apply_penalty("Traffic Cone Collision", 5)


# Connect signals from Inspection Checkpoints
func _connect_inspection_checkpoints() -> void:
	if not checkpoints_container:
		return
	for child in checkpoints_container.get_children():
		if child is InspectionCheckpoint:
			if not child.checkpoint_completed.is_connected(_on_checkpoint_completed):
				child.checkpoint_completed.connect(_on_checkpoint_completed)


func _set_checkpoints_active(active: bool) -> void:
	if not checkpoints_container:
		return
	for child in checkpoints_container.get_children():
		if child is InspectionCheckpoint:
			child.set_active(active)


func _on_checkpoint_completed(_chkpt_id: String) -> void:
	_inspected_count += 1
	if current_stage == TrainingStage.STAGE_1_INSPECTION and _inspected_count >= _total_checkpoints:
		advance_to_next_stage()


# Connect signals from ViewpointController
func _connect_viewpoint_controller() -> void:
	if not player:
		return
	var vp: ViewpointController = player.get_node_or_null("ViewpointController")
	if vp:
		if not vp.seated_state_changed.is_connected(_on_seated_state_changed):
			vp.seated_state_changed.connect(_on_seated_state_changed)


func _on_seated_state_changed(is_seated: bool) -> void:
	if is_seated:
		if current_stage == TrainingStage.STAGE_2_ENTER_CAB:
			advance_to_next_stage()
	else:
		if current_stage == TrainingStage.STAGE_6_PARK_FORKLIFT and forklift:
			# Verify parked near parking bay (-16, 0.2, 12) within 4.5m and forks flat on ground
			var parking_bay_pos = Vector3(-16.0, 0.2, 12.0)
			var in_bay = forklift.global_position.distance_to(parking_bay_pos) <= 5.5
			var forks_down = forklift.is_fork_at_travel_height() if forklift.has_method("is_fork_at_travel_height") else true
			if in_bay and forks_down:
				advance_to_next_stage()


# Connect signals from Forklift for pallet pickup & placement
func _connect_forklift_events() -> void:
	if not forklift:
		return
	if forklift.has_signal("pallet_released"):
		if not forklift.pallet_released.is_connected(_on_pallet_released):
			forklift.pallet_released.connect(_on_pallet_released)


func _on_pallet_released(pallet: Node3D) -> void:
	if current_stage == TrainingStage.STAGE_5_CARGO_MISSION and pallet:
		var drop_shelf_pos: Vector3 = Vector3(-16.0, 1.2, -14.0)
		if pallet.global_position.distance_to(drop_shelf_pos) < 4.5:
			advance_to_next_stage()


## Resets the current stage to its clean initial state before the trainee attempted it
func restart_current_stage() -> void:
	match current_stage:
		TrainingStage.STAGE_1_INSPECTION:
			_reset_checkpoints()
			if player and stage_markers_root:
				var m = _get_stage_marker(TrainingStage.STAGE_1_INSPECTION)
				if m:
					player.teleport_to(m.global_transform)
		TrainingStage.STAGE_2_ENTER_CAB:
			if player and player.viewpoint_controller and player.viewpoint_controller.is_seated:
				player.viewpoint_controller.exit_forklift()
			if player and stage_markers_root:
				var m = _get_stage_marker(TrainingStage.STAGE_2_ENTER_CAB)
				if m:
					player.teleport_to(m.global_transform)
		TrainingStage.STAGE_3_CONTROLS_CHECK:
			_reset_forklift_transform(Transform3D(Basis(), Vector3(0.0, 0.25, 12.0)))
			_ensure_player_seated()
			_lift_tested = false
			_tilt_tested = false
			_stage3_timer = 0.0
		TrainingStage.STAGE_4_DRIVE_SLALOM:
			_reset_traffic_cones()
			_reset_forklift_transform(Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 0.25, 8.5)))
			_ensure_player_seated()
		TrainingStage.STAGE_5_CARGO_MISSION:
			_reset_pallets()
			_reset_forklift_transform(Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 0.25, -8.0)))
			_ensure_player_seated()
		TrainingStage.STAGE_6_PARK_FORKLIFT:
			_reset_forklift_transform(Transform3D(Basis(), Vector3(-16.0, 0.25, 6.0)))
			_ensure_player_seated()
		TrainingStage.STAGE_7_COMPLETED:
			restart_entire_training()
			return

	start_stage(current_stage, false)


## Resets the entire training session from Stage 1 cleanly without reloading the scene
func restart_entire_training() -> void:
	osha_score = 100
	elapsed_time = 0.0
	cone_hits = 0
	total_penalties = 0
	is_training_active = true

	# Reset all world elements
	_reset_checkpoints()
	_reset_traffic_cones()
	_reset_pallets()
	_reset_forklift_transform(Transform3D(Basis(), Vector3(0.0, 0.25, 12.0)))

	# Dismount player if seated
	if player and player.viewpoint_controller and player.viewpoint_controller.is_seated:
		player.viewpoint_controller.exit_forklift()

	start_stage(TrainingStage.STAGE_1_INSPECTION, true)


func _reset_checkpoints() -> void:
	if not checkpoints_container:
		return
	for child in checkpoints_container.get_children():
		if child.has_method("reset_checkpoint"):
			child.reset_checkpoint()
	_inspected_count = 0


func _reset_traffic_cones() -> void:
	var cones = get_tree().get_nodes_in_group("traffic_cones")
	for cone in cones:
		if cone.has_method("reset_cone"):
			cone.reset_cone()


func _reset_pallets() -> void:
	var pallets = get_tree().get_nodes_in_group("pallets")
	for p in pallets:
		if p.has_method("reset_position"):
			p.reset_position()
	if forklift and "carried_pallet" in forklift:
		forklift.carried_pallet = null


func _reset_forklift_transform(target_transform: Transform3D) -> void:
	if not forklift:
		return
	forklift.linear_velocity = Vector3.ZERO
	forklift.angular_velocity = Vector3.ZERO
	forklift.steering = 0.0
	forklift.brake = 30.0
	forklift.engine_force = 0.0
	forklift.global_transform = target_transform
	if "fork" in forklift and forklift.fork:
		forklift.fork.position.y = -0.203
	if "mast" in forklift and forklift.mast:
		forklift.mast.rotation.x = 0.0
	if "carried_pallet" in forklift:
		forklift.carried_pallet = null


func _ensure_player_seated() -> void:
	if player and player.viewpoint_controller and forklift:
		if not player.viewpoint_controller.is_seated:
			player.viewpoint_controller.enter_forklift(forklift)
