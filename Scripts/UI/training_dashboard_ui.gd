extends Control
class_name TrainingDashboardUI

## In-Cab Diegetic VR Dashboard HUD Controller
## Displays live forklift telemetry and stage-gated instructions on the driver's console.

@export var forklift: VehicleBody3D
@export var training_manager: TrainingManager

# Speedometer & Transmission
@onready var speed_label: Label = $Panel/LeftCluster/SpeedRow/SpeedValue
@onready var speed_bar: ProgressBar = $Panel/LeftCluster/SpeedBar
@onready var gear_f: Label = $Panel/LeftCluster/GearRow/GearF
@onready var gear_n: Label = $Panel/LeftCluster/GearRow/GearN
@onready var gear_r: Label = $Panel/LeftCluster/GearRow/GearR

# Guidance & Score
@onready var stage_title_label: Label = $Panel/CenterCluster/StageTitle
@onready var instruction_label: Label = $Panel/CenterCluster/InstructionText
@onready var score_label: Label = $Panel/CenterCluster/ScoreBox/ScoreText

# Hydraulics
@onready var fork_height_bar: ProgressBar = $Panel/RightCluster/ForkBar
@onready var fork_height_label: Label = $Panel/RightCluster/ForkValue
@onready var mast_tilt_label: Label = $Panel/RightCluster/TiltValue

# Hazard Warning Banner
@onready var warning_banner: PanelContainer = $Panel/WarningBanner
@onready var warning_label: Label = $Panel/WarningBanner/WarningText

var _flash_timer: float = 0.0
var _color_yellow: Color = Color(1.0, 0.85, 0.2, 1.0)
var _color_active: Color = Color(0.2, 1.0, 0.4, 1.0)
var _color_inactive: Color = Color(0.35, 0.38, 0.45, 0.7)
var _color_warn: Color = Color(1.0, 0.75, 0.1, 1.0)
var _color_danger: Color = Color(0.95, 0.2, 0.2, 1.0)


func _ready() -> void:
	if not forklift:
		forklift = get_tree().get_first_node_in_group("forklift") as VehicleBody3D
	if not training_manager:
		var mgrs = get_tree().get_nodes_in_group("training_manager")
		if not mgrs.is_empty():
			training_manager = mgrs[0]

	if training_manager:
		training_manager.stage_changed.connect(_on_stage_changed)
		training_manager.penalty_applied.connect(_on_penalty_applied)

	_update_training_guidance()
	if warning_banner:
		warning_banner.visible = false


func _process(delta: float) -> void:
	_update_forklift_telemetry(delta)
	if training_manager and training_manager.current_stage == 2:
		_update_training_guidance()


func _update_forklift_telemetry(delta: float) -> void:
	if not forklift:
		return

	# 1. Speedometer
	var speed_kmh: float = forklift.get_speed_kmh() if forklift.has_method("get_speed_kmh") else 0.0
	if speed_label:
		speed_label.text = "%4.1f" % speed_kmh

	if speed_bar:
		speed_bar.value = clampf(speed_kmh, 0.0, 15.0)
		if speed_kmh > 10.0:
			speed_bar.modulate = _color_danger
		elif speed_kmh > 5.0:
			speed_bar.modulate = _color_warn
		else:
			speed_bar.modulate = _color_active

	# 2. Transmission Gear
	var gear: String = forklift.get_gear_state() if forklift.has_method("get_gear_state") else "N"
	_update_gear_lights(gear)

	# 3. Fork Elevation
	var fork_y: float = forklift.get_fork_height() if forklift.has_method("get_fork_height") else 0.0
	var norm_height = inverse_lerp(-0.203, 1.878, fork_y)
	if fork_height_bar:
		fork_height_bar.value = norm_height * 100.0

	if fork_height_label:
		var display_height = maxf(0.0, fork_y + 0.203)
		fork_height_label.text = "Ht: %3.2fm" % display_height

	# 4. Mast Tilt
	var tilt_deg: float = forklift.get_mast_tilt_deg() if forklift.has_method("get_mast_tilt_deg") else 0.0
	if mast_tilt_label:
		mast_tilt_label.text = "Tilt: %3.1f°" % tilt_deg

	# 5. Warning Checks
	_process_hazard_warnings(speed_kmh, fork_y, delta)


func _update_gear_lights(gear: String) -> void:
	if gear_f:
		gear_f.modulate = _color_active if gear == "F" else _color_inactive
	if gear_n:
		gear_n.modulate = _color_yellow if gear == "N" else _color_inactive
	if gear_r:
		gear_r.modulate = _color_danger if gear == "R" else _color_inactive


func _process_hazard_warnings(speed_kmh: float, fork_y: float, delta: float) -> void:
	if not warning_banner:
		return

	var is_fork_elevated: bool = speed_kmh > 1.2 and fork_y > -0.05
	var is_speeding: bool = speed_kmh > 10.0

	if is_speeding or is_fork_elevated:
		_flash_timer += delta * 6.0
		var flash_visible = fmod(_flash_timer, 2.0) < 1.0
		warning_banner.visible = flash_visible

		if warning_label:
			if is_speeding and is_fork_elevated:
				warning_label.text = "WARNING: SPEEDING AND HIGH FORKS"
			elif is_speeding:
				warning_label.text = "WARNING: SPEED LIMIT EXCEEDED (>10 KM/H)"
			else:
				warning_label.text = "WARNING: FORKS ELEVATED (>0.3M)"
	else:
		_flash_timer = 0.0
		warning_banner.visible = false


func _on_stage_changed(_stage: int, _stage_name: String) -> void:
	_update_training_guidance()


func _on_penalty_applied(_reason: String, _points: int, current_score: int) -> void:
	if score_label:
		var grade = "PASS" if current_score >= 70 else "FAIL"
		score_label.text = "OSHA Score: %d / 100 [%s]" % [current_score, grade]


func _update_training_guidance() -> void:
	if not training_manager:
		return

	var stage_idx = training_manager.current_stage
	if stage_title_label and stage_idx < TrainingManager.STAGE_NAMES.size():
		stage_title_label.text = TrainingManager.STAGE_NAMES[stage_idx].to_upper()

	if instruction_label and stage_idx < TrainingManager.STAGE_TASKS.size():
		var obj = TrainingManager.STAGE_OBJECTIVES[stage_idx]
		var tasks = TrainingManager.STAGE_TASKS[stage_idx]
		if stage_idx == 2 and "_lift_tested" in training_manager:
			var lift_st = "[CHECKED]" if training_manager._lift_tested else "[PRESS R / F]"
			var tilt_st = "[CHECKED]" if training_manager._tilt_tested else "[PRESS T / G]"
			tasks = "Hydraulics Checklist:\n• Fork Lift Up/Down: %s\n• Mast Tilt Front/Back: %s\n(Bay barrier opens once tested)" % [lift_st, tilt_st]
		instruction_label.text = "OBJECTIVE: %s\n\n%s" % [obj, tasks]

	if score_label:
		var score = training_manager.osha_score
		var grade = "PASS" if score >= 70 else "FAIL"
		score_label.text = "OSHA Score: %d / 100 [%s]" % [score, grade]
