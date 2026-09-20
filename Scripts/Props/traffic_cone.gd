extends RigidBody3D
class_name TrafficCone

## Reusable Training Traffic Cone
## Detects forklift impacts and cone knockdown events.
## Automatically registers in the "traffic_cones" group for ScoreManager.

signal cone_knocked(cone_instance: TrafficCone)

@export var penalty_points: int = 5
@export var knock_angle_threshold_deg: float = 30.0

var has_been_knocked: bool = false
var _initial_transform: Transform3D
var _up_vector_initial: Vector3 = Vector3.UP


func _ready() -> void:
	add_to_group("traffic_cones")
	_initial_transform = global_transform
	_up_vector_initial = global_transform.basis.y.normalized()

	# Configure physics contact monitoring
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

	# Connect trigger area if present
	var trigger: Area3D = get_node_or_null("HitArea") as Area3D
	if trigger:
		trigger.body_entered.connect(_on_hit_area_entered)
		trigger.area_entered.connect(_on_hit_area_entered)


func _physics_process(_delta: float) -> void:
	if has_been_knocked:
		return

	# Tilt detection: if cone tips over beyond threshold angle, count as knocked
	var current_up = global_transform.basis.y.normalized()
	var angle_diff = rad_to_deg(_up_vector_initial.angle_to(current_up))
	if angle_diff >= knock_angle_threshold_deg:
		_trigger_knock("tilt")


func _on_body_entered(body: Node) -> void:
	if has_been_knocked:
		return

	if body is VehicleBody3D or body.is_in_group("forklift") or body is CharacterBody3D:
		_trigger_knock("body_collision: " + body.name)


func _on_hit_area_entered(other: Node) -> void:
	if has_been_knocked:
		return

	if other is VehicleBody3D or other.is_in_group("forklift") or other.get_parent().is_in_group("forklift"):
		_trigger_knock("area_overlap: " + other.name)


func _trigger_knock(_reason: String = "") -> void:
	if has_been_knocked:
		return
	has_been_knocked = true
	cone_knocked.emit(self)


## Resets the cone back to its initial spawn transform and clears knocked state
func reset_cone() -> void:
	has_been_knocked = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = _initial_transform
	sleeping = false
