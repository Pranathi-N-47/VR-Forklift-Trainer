extends CanvasLayer
class_name PenaltyToastHUD

## Penalty Toast, Stage Transition, and Stage-Gated Briefing HUD
## Announces "STAGE FINISHED" upon completion, and presents detailed
## instructions before each stage starts without auto-dismissal.
## Trainee must click CONTINUE to begin each stage.

@export var training_manager: TrainingManager

# Containers & Labels
@onready var finished_box: PanelContainer = $TopContainer/FinishedBox
@onready var finished_label: Label = $TopContainer/FinishedBox/FinishedLabel

@onready var briefing_box: PanelContainer = $BriefingContainer/BriefingBox
@onready var briefing_title: Label = $BriefingContainer/BriefingBox/VBox/TitleLabel
@onready var briefing_objective: Label = $BriefingContainer/BriefingBox/VBox/ObjectiveLabel
@onready var briefing_tasks: Label = $BriefingContainer/BriefingBox/VBox/TasksLabel
@onready var briefing_criteria: Label = $BriefingContainer/BriefingBox/VBox/CriteriaLabel
@onready var btn_continue: Button = $BriefingContainer/BriefingBox/VBox/BtnContinue

@onready var penalty_box: PanelContainer = $CenterContainer/PenaltyBox
@onready var penalty_label: Label = $CenterContainer/PenaltyBox/PenaltyLabel

@onready var buzzer_audio: AudioStreamPlayer = $BuzzerAudio
@onready var chime_audio: AudioStreamPlayer = $ChimeAudio
@onready var click_audio: AudioStreamPlayer = get_node_or_null("ClickAudio")

var _finished_timer: float = 0.0
var _penalty_timer: float = 0.0


func _ready() -> void:
	if not training_manager:
		var mgrs = get_tree().get_nodes_in_group("training_manager")
		if not mgrs.is_empty():
			training_manager = mgrs[0]

	if training_manager:
		training_manager.penalty_applied.connect(_on_penalty_applied)
		if training_manager.has_signal("stage_finished"):
			training_manager.stage_finished.connect(_on_stage_finished)
		if training_manager.has_signal("stage_started"):
			training_manager.stage_started.connect(_on_stage_started)

	if btn_continue:
		btn_continue.pressed.connect(_on_continue_pressed)

	if finished_box:
		finished_box.visible = false
	if briefing_box:
		briefing_box.visible = false
	if penalty_box:
		penalty_box.visible = false


func _process(delta: float) -> void:
	if _finished_timer > 0.0:
		_finished_timer -= delta
		if _finished_timer <= 0.0 and finished_box:
			finished_box.visible = false

	if _penalty_timer > 0.0:
		_penalty_timer -= delta
		if _penalty_timer <= 0.0 and penalty_box:
			penalty_box.visible = false


func _on_continue_pressed() -> void:
	if click_audio:
		click_audio.play()
	if briefing_box:
		briefing_box.visible = false
	# Recapture mouse for gameplay
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_penalty_applied(reason: String, points: int, current_score: int) -> void:
	if not penalty_box or not penalty_label:
		return

	penalty_label.text = "PENALTY: -%d POINTS\nREASON: %s\nCURRENT SCORE: %d / 100" % [points, reason.to_upper(), current_score]
	penalty_box.visible = true
	_penalty_timer = 2.8

	if buzzer_audio:
		buzzer_audio.play()


func _on_stage_finished(prev_stage: int, stage_name: String) -> void:
	if not finished_box or not finished_label:
		return

	finished_label.text = "STAGE FINISHED\n%s" % stage_name.to_upper()
	finished_box.visible = true
	_finished_timer = 2.5

	if chime_audio:
		chime_audio.play()


func _on_stage_started(stage: int, stage_name: String, objective: String, tasks: String, completion: String) -> void:
	# For stage 7 (evaluation/report card), do not display the standard briefing card
	if stage == 6:
		if briefing_box:
			briefing_box.visible = false
		return

	if not briefing_box:
		return

	if briefing_title:
		briefing_title.text = stage_name.to_upper()
	if briefing_objective:
		briefing_objective.text = "OBJECTIVE: %s" % objective
	if briefing_tasks:
		briefing_tasks.text = "TASKS:\n%s" % tasks
	if briefing_criteria:
		briefing_criteria.text = "COMPLETION CRITERIA: %s" % completion

	briefing_box.visible = true
	# Release mouse so the user can read the briefing and click CONTINUE
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
