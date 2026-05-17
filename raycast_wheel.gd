extends RayCast3D
class_name RaycastWheel

@export var spring_strength := 100
@export var spring_damping := 2.0
@export var rest_distance := 0.5
@export var stick_factor := 0.0
@export var wheel_radius := 0.4
@export var is_motor := false
@export var grip_curve : Curve

@onready var wheel: Node3D = get_child(0)
