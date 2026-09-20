extends Node
class_name TrainingManager

## Master Training State Machine for VR Forklift Operator Training
## Coordinates all 7 training stages, teleports the player to stage locations,
## enforces physical stage boundary barriers, and tracks OSHA compliance.

signal stage_changed(new_stage: int, stage_name: String)
signal penalty_applied(reason: String, points: int, current_score: int)
signal training_completed(final_score: int, elapsed_time: float)

enum TrainingStage {
	STAGE_1_INSPECTION = 0,     # Pre-operation 4-point walkaround
	STAGE_2_ENTER_CAB = 1,      # Approach driver door & mount cab
	STAGE_3_CONTROLS_CHECK = 2, # Mast fork raise & lower check
	STAGE_4_DRIVE_SLALOM = 3,   # Navigate cone slalom course
	STAGE_5_CARGO_MISSION = 4,  # Ground Pickup -> Transport -> Raised Rack Dropoff
	STAGE_6_PARK_FORKLIFT = 5,  # Park in designated bay, lower forks, shutdown
	STAGE_7_COMPLETED = 6       # Training summary & OSHA evaluation
}

const STAGE_NAMES: Array[String] = [
	"Stage 1: Pre-Operation Inspection",
	"Stage 2: Mount Forklift Cab",
	"Stage 3: Controls Familiarization (Mast Lift)",
	"Stage 4: Driving Maneuver & Cone Slalom",
	"Stage 5: Cargo Transport Mission (Pickup to Raised Rack)",
	"Stage 6: Parking Bay & Shutdown",
	"Stage 7: OSHA Certification Completed"
]

const STAGE_INSTRUCTIONS: Array[String] = [
	"Walk around the forklift and inspect all 4 yellow checkpoints:\n• Front Mast/Forks  • Tires/Lug Nuts  • Rear Counterweight  • Cab Guard",
	"Approach the driver's side door and press [E] / VR Button to mount the cab.",
	"Test the hydraulic mast: Raise and lower the forks using [Up/Down] arrows or VR stick.",
	"Carefully drive through the marked training lane without touching any traffic cones.",
	"Cargo Mission:\n1. Slide forks under pallet on ground\n2. Transport across lane to Drop Zone\n3. Raise forks to 1.2m and place pallet squarely on the raised rack shelf\n4. Lower forks and back out smoothly",
	"Drive into the designated parking bay, lower forks completely to the ground, and dismount with [E].",
	"Training Complete! Review your OSHA score and safety evaluation below."
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

# Stage tracking data
var _inspected_count: int = 0
var _total_checkpoints: int = 4


func _ready() -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player") as XRPlayer
	if not forklift:
		forklift = get_tree().get_first_node_in_group("forklift") as VehicleBody3D

	# Connect traffic cone knocked signals
	_connect_traffic_cones()

	# Connect inspection checkpoints
	_connect_inspection_checkpoints()

	# Connect viewpoint controller
	_connect_viewpoint_controller()

	# Initialize at Stage 1
	start_stage(TrainingStage.STAGE_1_INSPECTION, true)


func _process(delta: float) -> void:
	if not is_training_active:
		return

	elapsed_time += delta
	_handle_debug_keys()
	_update_displays()


func _handle_debug_keys() -> void:
	# Debug quick jump keys 1 through 7
	for key_idx in range(7):
		var action_key = KEY_1 + key_idx
		if Input.is_physical_key_pressed(action_key):
			if current_stage != key_idx:
				start_stage(key_idx, true)
				return


## Starts a specific stage, updates instructions, adjusts physical barriers, and teleports player
func start_stage(stage_index: int, teleport_player: bool = true) -> void:
	current_stage = clampi(stage_index, 0, 6)
	stage_changed.emit(current_stage, STAGE_NAMES[current_stage])

	# Update physical stage boundary barriers
	_update_stage_barriers(current_stage)

	# Teleport player to stage location
	if teleport_player and stage_markers_root and player:
		var marker = _get_stage_marker(current_stage)
		if marker:
			player.teleport_to(marker.global_transform)

	# Setup stage specific behaviors
	match current_stage:
		TrainingStage.STAGE_1_INSPECTION:
			_inspected_count = 0
			_set_checkpoints_active(true)
		TrainingStage.STAGE_2_ENTER_CAB:
			_set_checkpoints_active(false)
		TrainingStage.STAGE_7_COMPLETED:
			is_training_active = false
			training_completed.emit(osha_score, elapsed_time)

	_update_displays()


func advance_to_next_stage() -> void:
	if current_stage < TrainingStage.STAGE_7_COMPLETED:
		start_stage(current_stage + 1, true)


func apply_penalty(reason: String, points: int) -> void:
	osha_score = maxi(0, osha_score - points)
	penalty_applied.emit(reason, points, osha_score)
	_update_displays()


## Updates physical barrier collisions so players cannot enter reserved areas of other stages
func _update_stage_barriers(stage_idx: int) -> void:
	if not stage_barriers_root:
		return

	# Barrier 1: Forklift Bay Exit Barrier (blocks driving out of bay during inspection and cab entry)
	var bay_barrier = stage_barriers_root.get_node_or_null("Barrier_ForkliftBay")
	if bay_barrier:
		var bay_closed = stage_idx < TrainingStage.STAGE_3_CONTROLS_CHECK
		_set_barrier_state(bay_barrier, bay_closed)

	# Barrier 2: Slalom Course Exit / Staging Gate (blocks entry into cargo area during slalom and earlier)
	var slalom_barrier = stage_barriers_root.get_node_or_null("Barrier_SlalomExit")
	if slalom_barrier:
		var slalom_closed = stage_idx < TrainingStage.STAGE_5_CARGO_MISSION
		_set_barrier_state(slalom_barrier, slalom_closed)

	# Barrier 3: Parking Bay Barrier (blocks parking bay until parking stage)
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


func _update_displays() -> void:
	if guidance_display:
		var stage_title = STAGE_NAMES[current_stage]
		var instruction = STAGE_INSTRUCTIONS[current_stage]
		guidance_display.text = "=== %s ===\n\n%s" % [stage_title, instruction]

	if score_display:
		var mins = int(elapsed_time) / 60
		var secs = int(elapsed_time) % 60
		var grade = "PASS" if osha_score >= 70 else "FAIL"
		score_display.text = "OSHA Score: %d / 100 [%s]\nTime: %02d:%02d\n(Debug: Press 1-7 to jump stages)" % [
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
		if current_stage == TrainingStage.STAGE_6_PARK_FORKLIFT:
			advance_to_next_stage()
