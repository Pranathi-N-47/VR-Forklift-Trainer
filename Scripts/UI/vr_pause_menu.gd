extends CanvasLayer
class_name VRPauseMenu

## Dual-Input Pause & Settings Menu for XR Simulator and Desktop Testing
## Toggled via Esc, Tab, or VR Menu button.
## Automatically frees the mouse cursor for instant clickability without 6-DOF gymnastics.

@export var training_manager: TrainingManager
@export var player: XRPlayer

@onready var modal_panel: PanelContainer = $CenterContainer/ModalPanel
@onready var tab_container: TabContainer = $CenterContainer/ModalPanel/VBox/TabContainer
@onready var btn_resume: Button = $CenterContainer/ModalPanel/VBox/TabContainer/Session/VBox/BtnResume
@onready var btn_restart_stage: Button = $CenterContainer/ModalPanel/VBox/TabContainer/Session/VBox/BtnRestartStage
@onready var btn_restart_all: Button = $CenterContainer/ModalPanel/VBox/TabContainer/Session/VBox/BtnRestartAll

# Settings Controls
@onready var snap_turn_options: OptionButton = $CenterContainer/ModalPanel/VBox/TabContainer/Comfort/VBox/SnapTurnRow/OptionSnap
@onready var mouse_sens_slider: HSlider = $CenterContainer/ModalPanel/VBox/TabContainer/Comfort/VBox/MouseSensRow/SliderSens
@onready var btn_recalibrate: Button = $CenterContainer/ModalPanel/VBox/TabContainer/Comfort/VBox/BtnRecalibrate

# Audio Sliders
@onready var slider_master: HSlider = $CenterContainer/ModalPanel/VBox/TabContainer/Audio/VBox/MasterRow/SliderMaster
@onready var slider_engine: HSlider = $CenterContainer/ModalPanel/VBox/TabContainer/Audio/VBox/EngineRow/SliderEngine
@onready var slider_ui: HSlider = $CenterContainer/ModalPanel/VBox/TabContainer/Audio/VBox/UIRow/SliderUI

# Audio Player
@onready var click_sfx: AudioStreamPlayer = $ClickSFX

var is_menu_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if not training_manager:
		var mgrs = get_tree().get_nodes_in_group("training_manager")
		if not mgrs.is_empty():
			training_manager = mgrs[0]

	if not player:
		player = get_tree().get_first_node_in_group("player") as XRPlayer

	visible = false
	is_menu_open = false

	_connect_ui_signals()
	_init_settings_values()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE or event.physical_keycode == KEY_TAB:
			toggle_menu()


func toggle_menu() -> void:
	is_menu_open = not is_menu_open
	visible = is_menu_open
	get_tree().paused = is_menu_open

	if is_menu_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_play_click()
	else:
		# If desktop player active, recapture mouse
		if player and not player.is_xr_active:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _connect_ui_signals() -> void:
	if btn_resume:
		btn_resume.pressed.connect(func():
			_play_click()
			toggle_menu()
		)
	if btn_restart_stage:
		btn_restart_stage.pressed.connect(func():
			_play_click()
			if training_manager:
				training_manager.restart_current_stage()
			toggle_menu()
		)
	if btn_restart_all:
		btn_restart_all.pressed.connect(func():
			_play_click()
			if training_manager:
				training_manager.restart_entire_training()
			toggle_menu()
		)

	if snap_turn_options:
		snap_turn_options.item_selected.connect(_on_snap_turn_selected)

	if mouse_sens_slider:
		mouse_sens_slider.value_changed.connect(_on_mouse_sens_changed)

	if btn_recalibrate:
		btn_recalibrate.pressed.connect(_on_recalibrate_pressed)

	if slider_master:
		slider_master.value_changed.connect(func(val): _set_bus_vol(0, val))
	if slider_engine:
		slider_engine.value_changed.connect(func(val): _set_bus_vol(2, val))
	if slider_ui:
		slider_ui.value_changed.connect(func(val): _set_bus_vol(3, val))


func _init_settings_values() -> void:
	if snap_turn_options:
		snap_turn_options.clear()
		snap_turn_options.add_item("Snap 30°", 0)
		snap_turn_options.add_item("Snap 45° (Default)", 1)
		snap_turn_options.add_item("Snap 90°", 2)
		snap_turn_options.select(1)

	if mouse_sens_slider and player:
		mouse_sens_slider.value = player.mouse_sensitivity * 1000.0


func _on_snap_turn_selected(index: int) -> void:
	_play_click()
	if not player:
		return
	match index:
		0: player.snap_turn_angle_deg = 30.0
		1: player.snap_turn_angle_deg = 45.0
		2: player.snap_turn_angle_deg = 90.0


func _on_mouse_sens_changed(value: float) -> void:
	if player:
		player.mouse_sensitivity = value / 1000.0


func _on_recalibrate_pressed() -> void:
	_play_click()
	if not player:
		return
	player._cam_pitch = 0.0
	if player.xr_camera:
		player.xr_camera.rotation = Vector3.ZERO


func _set_bus_vol(bus_idx: int, percent: float) -> void:
	if bus_idx < AudioServer.bus_count:
		if percent <= 0.01:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			var db = linear_to_db(percent / 100.0)
			AudioServer.set_bus_volume_db(bus_idx, db)


func _play_click() -> void:
	if click_sfx:
		click_sfx.play()
