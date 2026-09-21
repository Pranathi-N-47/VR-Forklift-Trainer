extends CanvasLayer
class_name MainMenu

## Simulator Startup Screen
## Collects operator ID and initiates the 7-stage OSHA training program.

signal training_started(operator_name: String)

@export var training_manager: TrainingManager
@export var player: XRPlayer

@onready var name_input: LineEdit = $CenterContainer/Panel/VBox/NameRow/NameInput
@onready var btn_start: Button = $CenterContainer/Panel/VBox/BtnStartTraining
@onready var click_sfx: AudioStreamPlayer = $ClickSFX


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if not training_manager:
		var mgrs = get_tree().get_nodes_in_group("training_manager")
		if not mgrs.is_empty():
			training_manager = mgrs[0]

	if not player:
		player = get_tree().get_first_node_in_group("player") as XRPlayer

	if btn_start:
		btn_start.pressed.connect(_on_start_pressed)


func _on_start_pressed() -> void:
	_play_click()
	var op_name: String = name_input.text.strip_edges() if name_input else ""
	if op_name.is_empty():
		op_name = "Trainee #101"

	training_started.emit(op_name)
	visible = false

	if training_manager:
		training_manager.start_stage(TrainingManager.TrainingStage.STAGE_1_INSPECTION, true)


func _play_click() -> void:
	if click_sfx:
		click_sfx.play()
