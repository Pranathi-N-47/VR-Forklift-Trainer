extends Area3D
class_name InspectionCheckpoint

## Interactive 3D Pre-Operation Inspection Checkpoint
## Highlights inspection zones around the forklift during Stage 1.
## Emits checkpoint_completed when player approaches and completes inspection.

signal checkpoint_completed(checkpoint_id: String)

@export var checkpoint_id: String = "Front_Mast"
@export var checkpoint_title: String = "Mast & Forks"
@export var inspection_time_required: float = 1.2
@export var is_inspected: bool = false
@export var is_active: bool = true

@onready var label_3d: Label3D = $Label3D
@onready var indicator_mesh: MeshInstance3D = $RingMesh

var _inspection_timer: float = 0.0
var _player_in_area: bool = false
var _initial_mesh_pos_y: float = 0.0
var _anim_time: float = 0.0

var _mat_pending: StandardMaterial3D
var _mat_complete: StandardMaterial3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if indicator_mesh:
		_initial_mesh_pos_y = indicator_mesh.position.y

	_setup_materials()
	_update_visuals()


func _setup_materials() -> void:
	# Yellow pulsing material for pending
	_mat_pending = StandardMaterial3D.new()
	_mat_pending.albedo_color = Color(1.0, 0.8, 0.1, 0.85)
	_mat_pending.emission_enabled = true
	_mat_pending.emission = Color(1.0, 0.7, 0.0)
	_mat_pending.emission_energy_multiplier = 1.2
	_mat_pending.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Green solid material for completed
	_mat_complete = StandardMaterial3D.new()
	_mat_complete.albedo_color = Color(0.2, 0.9, 0.3, 0.9)
	_mat_complete.emission_enabled = true
	_mat_complete.emission = Color(0.1, 0.8, 0.2)
	_mat_complete.emission_energy_multiplier = 0.8
	_mat_complete.cull_mode = BaseMaterial3D.CULL_DISABLED


func _process(delta: float) -> void:
	if not is_active or is_inspected:
		return

	_anim_time += delta * 3.0
	# Subtle hover bobbing
	if indicator_mesh:
		indicator_mesh.position.y = _initial_mesh_pos_y + sin(_anim_time) * 0.05
		indicator_mesh.rotate_y(delta * 1.5)

	# Progress inspection timer if player is inside area
	if _player_in_area:
		_inspection_timer += delta
		var progress: float = clampf(_inspection_timer / inspection_time_required, 0.0, 1.0)
		if label_3d:
			label_3d.text = "%s\nInspecting... %d%%" % [checkpoint_title, int(progress * 100)]

		if _inspection_timer >= inspection_time_required:
			complete_inspection()


func set_active(active: bool) -> void:
	is_active = active
	visible = active
	monitoring = active
	monitorable = active


func complete_inspection() -> void:
	if is_inspected:
		return

	is_inspected = true
	_update_visuals()
	checkpoint_completed.emit(checkpoint_id)


func reset_checkpoint() -> void:
	is_inspected = false
	_inspection_timer = 0.0
	_player_in_area = false
	_update_visuals()


func _update_visuals() -> void:
	if not label_3d:
		return

	if is_inspected:
		label_3d.text = "✓ %s (Checked)" % checkpoint_title
		label_3d.modulate = Color(0.3, 1.0, 0.4)
		if indicator_mesh:
			indicator_mesh.material_override = _mat_complete
	else:
		label_3d.text = "[ %s ]\nStep close to inspect" % checkpoint_title
		label_3d.modulate = Color(1.0, 0.9, 0.3)
		if indicator_mesh:
			indicator_mesh.material_override = _mat_pending


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D or body.name.contains("Player") or body.get_meta("is_player", false):
		_player_in_area = true


func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D or body.name.contains("Player") or body.get_meta("is_player", false):
		_player_in_area = false
		if not is_inspected:
			_inspection_timer = 0.0
			_update_visuals()
