extends RigidBody3D

@export var wheels: Array[RayCast3D]
@export var spring_strength := 100.0
@export var spring_damping := 2.0
@export var rest_dist := 0.5

func _physics_process(_delta: float) -> void:
	for wheel in wheels: 
		_do_single_wheel_suspension(wheel)

func _get_point_velocity(point: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - global_position)

func _do_single_wheel_suspension(suspension_ray: RayCast3D) -> void:
	if suspension_ray.is_colliding():
		var contact := suspension_ray.get_collision_point()
		var spring_up_dir := suspension_ray.global_transform.basis.y
		
		# 1. Use the attachment point (top of the ray), not the ground contact point
		var ray_origin := suspension_ray.global_position
		var spring_len := ray_origin.distance_to(contact)
		var offset := rest_dist - spring_len
		
		# Hooke's Law: F = -k * x
		var spring_force := spring_strength * offset
		
		# 2. Get velocity at the wheel attachment point
		var wheel_vel := _get_point_velocity(ray_origin)
		var relative_vel := spring_up_dir.dot(wheel_vel)
		
		# 3. Fix Sign: Damping must directly oppose the direction of spring travel
		var spring_damp_force := spring_damping * relative_vel
		
		# Combine forces (F_total = F_spring - F_damping)
		var force_amount := spring_force - spring_damp_force
		var force_vector := force_amount * spring_up_dir
		
		# 4. Apply the force exactly where the wheel attaches to the chassis
		var force_pos_offset := ray_origin - global_position
		apply_force(force_vector, force_pos_offset)
