extends CanvasLayer
class_name ResultsScreen

## Final Stage 7: OSHA Certification & Evaluation Report Card
## Displays official training report card with score, time, infractions,
## Pass/Fail threshold (>= 70%), and stage quick-jump instructions.

@export var training_manager: TrainingManager

@onready var modal: PanelContainer = $CenterContainer/Modal
@onready var grade_stamp: Label = $CenterContainer/Modal/VBox/StampBox/GradeStamp
@onready var summary_label: Label = $CenterContainer/Modal/VBox/ScorecardBox/Margin/VBox/SummaryLabel
@onready var infractions_label: Label = $CenterContainer/Modal/VBox/ScorecardBox/Margin/VBox/InfractionsLabel
@onready var time_label: Label = $CenterContainer/Modal/VBox/ScorecardBox/Margin/VBox/TimeLabel
@onready var tip_label: Label = $CenterContainer/Modal/VBox/TipLabel
@onready var btn_retry: Button = $CenterContainer/Modal/VBox/ButtonRow/BtnRetry
@onready var btn_quit: Button = $CenterContainer/Modal/VBox/ButtonRow/BtnQuit

@onready var sfx_pass: AudioStreamPlayer = $SFXPass
@onready var sfx_fail: AudioStreamPlayer = $SFXFail
@onready var sfx_click: AudioStreamPlayer = $SFXClick


func _ready() -> void:
	visible = false

	if not training_manager:
		var mgrs = get_tree().get_nodes_in_group("training_manager")
		if not mgrs.is_empty():
			training_manager = mgrs[0]

	if training_manager:
		training_manager.training_completed.connect(_on_training_completed)

	if btn_retry:
		btn_retry.pressed.connect(_on_retry_pressed)
	if btn_quit:
		btn_quit.pressed.connect(_on_quit_pressed)


func _on_training_completed(final_score: int, elapsed_time: float, cone_hits: int, total_penalties: int) -> void:
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var is_passed: bool = final_score >= 70
	var mins = int(elapsed_time) / 60
	var secs = int(elapsed_time) % 60

	# 1. Official Pass/Fail Stamp
	if grade_stamp:
		if is_passed:
			grade_stamp.text = "[PASS - OSHA CERTIFIED]"
			grade_stamp.modulate = Color(0.2, 0.95, 0.4, 1.0)
		else:
			grade_stamp.text = "[FAIL - NON-COMPLIANT]"
			grade_stamp.modulate = Color(0.95, 0.25, 0.25, 1.0)

	# 2. Scorecard breakdown
	if summary_label:
		summary_label.text = "• Base Inspection Score : 100 Points\n• Net Safety Deductions : -%d Points\n• Final Operator Score   : %d / 100 (Pass threshold: >= 70%%)" % [
			total_penalties, final_score
		]

	# 3. Infractions detail
	if infractions_label:
		infractions_label.text = "Safety Infractions Recorded:\n• Traffic Cone Collisions: %d occurrences (-%d points)\n• Unsafe Maneuvering Deductions: -%d points" % [
			cone_hits, cone_hits * 5, maxi(0, total_penalties - (cone_hits * 5))
		]

	# 4. Total duration
	if time_label:
		time_label.text = "Total Training Run Time: %02d min %02d sec" % [mins, secs]

	if tip_label:
		tip_label.text = "(Tip for testing: Pressing number keys 1 through 7 on your keyboard allows quick jumping between any of the stages at any time)."

	# Audio feedback
	if is_passed and sfx_pass:
		sfx_pass.play()
	elif not is_passed and sfx_fail:
		sfx_fail.play()


func _on_retry_pressed() -> void:
	if sfx_click:
		sfx_click.play()
	visible = false
	if training_manager:
		training_manager.restart_entire_training()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_quit_pressed() -> void:
	if sfx_click:
		sfx_click.play()
	get_tree().quit()
