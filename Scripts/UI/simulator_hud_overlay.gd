extends CanvasLayer
class_name SimulatorHUDOverlay

## Simulator HUD Overlay for OpenXR Device Simulator and Desktop Playtesting
## Provides an on-screen controls cheat sheet (toggleable via H / F1)
## and persistent status telemetry.

@export var training_manager: TrainingManager
@export var forklift: VehicleBody3D

@onready var controls_card: PanelContainer = $ControlsCard
@onready var stage_label: Label = $TopLeftStatus/VBox/StageLabel
@onready var score_label: Label = $TopLeftStatus/VBox/ScoreLabel
@onready var telemetry_label: Label = $TopLeftStatus/VBox/TelemetryLabel

var _card_visible: bool = true


func _ready() -> void:
	if not training_manager:
		var mgrs = get_tree().get_nodes_in_group("training_manager")
		if not mgrs.is_empty():
			training_manager = mgrs[0]

	if not forklift:
		forklift = get_tree().get_first_node_in_group("forklift") as VehicleBody3D

	if training_manager:
		training_manager.stage_changed.connect(_on_stage_changed)
		training_manager.penalty_applied.connect(_on_penalty_applied)

	_update_stage_display()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F1:
			_toggle_controls_card()


func _process(_delta: float) -> void:
	_update_telemetry()


func _toggle_controls_card() -> void:
	_card_visible = not _card_visible
	if controls_card:
		controls_card.visible = _card_visible


func _update_telemetry() -> void:
	if not forklift or not telemetry_label:
		return

	var speed = forklift.get_speed_kmh() if forklift.has_method("get_speed_kmh") else 0.0
	var fork_h = forklift.get_fork_height() if forklift.has_method("get_fork_height") else 0.0
	var gear = forklift.get_gear_state() if forklift.has_method("get_gear_state") else "N"
	telemetry_label.text = "Speed: %3.1f km/h | Gear: [%s] | Forks: %3.2fm" % [speed, gear, maxf(0.0, fork_h + 0.2)]


func _on_stage_changed(_stage: int, _stage_name: String) -> void:
	_update_stage_display()


func _on_penalty_applied(_reason: String, _points: int, current_score: int) -> void:
	if score_label:
		var grade = "PASS" if current_score >= 70 else "FAIL"
		score_label.text = "OSHA Score: %d / 100 [%s]" % [current_score, grade]


func _update_stage_display() -> void:
	if not training_manager:
		return

	var stage_idx = training_manager.current_stage
	if stage_label and stage_idx < TrainingManager.STAGE_NAMES.size():
		stage_label.text = TrainingManager.STAGE_NAMES[stage_idx]

	if score_label:
		var score = training_manager.osha_score
		var grade = "PASS" if score >= 70 else "FAIL"
		score_label.text = "OSHA Score: %d / 100 [%s]" % [score, grade]
