extends RigidBody3D
class_name PalletCargo

## Cargo Pallet Component for VR Material Handling
## Manages cargo weight, fork pocket alignment detection, pickup detection, and physics carry lock.

signal pallet_aligned_with_forks(is_aligned: bool)
signal forks_inserted(fork_node: Node3D)
signal forks_extracted()

@export var cargo_name: String = "Standard Pallet"
@export var cargo_weight: float = 25.0 ## Weight in kg (empty pallet ~25kg, with drums 250kg - 450kg)
@export var max_alignment_angle_deg: float = 18.0 ## Maximum yaw misalignment tolerance for clean fork insertion

@onready var pickup_area: Area3D = $PickupArea

var is_carried: bool = false
var _initial_transform: Transform3D
var active_forks: Node3D = null


func _ready() -> void:
	add_to_group("pallets")
	_initial_transform = global_transform
	mass = cargo_weight

	call_deferred("_ignore_forklift_collision")

	if pickup_area:
		pickup_area.area_entered.connect(_on_pickup_area_entered)
		pickup_area.area_exited.connect(_on_pickup_area_exited)
		pickup_area.body_entered.connect(_on_pickup_body_entered)
		pickup_area.body_exited.connect(_on_pickup_body_exited)


func _ignore_forklift_collision() -> void:
	var fl = get_tree().get_first_node_in_group("forklift")
	if fl and fl is CollisionObject3D:
		add_collision_exception_with(fl)


## Returns total cargo mass in kg
func get_cargo_weight() -> float:
	return cargo_weight


## Evaluates whether the incoming forks are aligned squarely with the pallet's fork pockets
func is_aligned_with_forks(fork_transform: Transform3D) -> bool:
	# Pallet forward/pocket entry axis (Z axis)
	var pallet_forward: Vector3 = global_transform.basis.z.normalized()
	var fork_forward: Vector3 = fork_transform.basis.z.normalized()

	# Project to horizontal plane
	pallet_forward.y = 0.0
	pallet_forward = pallet_forward.normalized()
	fork_forward.y = 0.0
	fork_forward = fork_forward.normalized()

	# In Godot, forks approach along Z or -Z depending on vehicle orientation
	var dot: float = absf(pallet_forward.dot(fork_forward))
	var angle_deg: float = rad_to_deg(acos(clampf(dot, 0.0, 1.0)))

	var aligned: bool = angle_deg <= max_alignment_angle_deg
	pallet_aligned_with_forks.emit(aligned)
	return aligned


## Called by Dev B's fork CarryPoint when attaching or detaching the pallet
func set_carried(carried: bool) -> void:
	is_carried = carried
	if is_carried:
		# Freeze physics while attached to avoid physics contact jitter during transport
		freeze = true
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
	else:
		# Restore active physics upon placement in drop zone
		freeze = false
		sleeping = false
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO


## Resets pallet back to its initial staging position
func reset_position() -> void:
	set_carried(false)
	global_transform = _initial_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = false


func _on_pickup_area_entered(area: Area3D) -> void:
	if area.name == "CarryPoint" or area.is_in_group("forks"):
		active_forks = area
		forks_inserted.emit(active_forks)


func _on_pickup_area_exited(area: Area3D) -> void:
	if area == active_forks:
		active_forks = null
		forks_extracted.emit()


func _on_pickup_body_entered(body: Node) -> void:
	if body.is_in_group("forks") or body.name == "Forks":
		active_forks = body as Node3D
		forks_inserted.emit(active_forks)


func _on_pickup_body_exited(body: Node) -> void:
	if body == active_forks:
		active_forks = null
		forks_extracted.emit()
