extends RigidBody3D

@export var wheels: Array[RaycastWheel]
@export var acceleration := 600.0

var motor_input := 0.0

func _unhandled_input(event: InputEvent) -> void:
	
	if event.is_action("accelerate"):
		motor_input = event.get_action_strength("accelerate")
	elif event.is_action_released("accelerate"):
		motor_input = 0
	
	if event.is_action("brake"):
		var brake_force = event.get_action_strength("brake")
		brake_force = -brake_force
		motor_input = brake_force
	elif event.is_action_released("brake"):
		motor_input = 0
		

func _physics_process(delta: float) -> void:
	for wheel in wheels: 
		_do_single_wheel_suspension(wheel)
		_do_single_wheel_acceleration(wheel)


func _get_point_velocity(point: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - global_position)
	
	
func _do_single_wheel_acceleration(ray: RaycastWheel) -> void:
	if ray.is_colliding() and ray.is_motor:
		var forward_dir := -ray.global_basis.z
		var contact := ray.wheel.global_position
		var force_vector := forward_dir * acceleration * motor_input
		print(motor_input)
		print(forward_dir*acceleration)
		var force_pos := contact - global_position
		
		apply_force(force_vector, force_pos)
		DebugDraw3D.draw_arrow_ray(contact, force_vector/mass, 2.5, Color.RED, 0.1)
		
		
func _do_single_wheel_suspension(ray: RaycastWheel) -> void:
	if ray.is_colliding():
		
		ray.target_position.y = -(ray.rest_distance + ray.wheel_radius + ray.stick_factor)
		var contact := ray.get_collision_point()
		var spring_up_dir := ray.global_transform.basis.y
		var spring_len := ray.global_position.distance_to(contact) - ray.wheel_radius
		var offset := ray.rest_distance - spring_len
		
		ray.wheel.position.y = -spring_len
		
		var spring_force := ray.spring_strength * offset
		
		#Damping force = damping * velative velocity
		var world_vel := _get_point_velocity(contact)
		var relative_vel := spring_up_dir.dot(world_vel)
		var spring_damp_force := ray.spring_damping * relative_vel
		
		var force_vector := (spring_force - spring_damp_force) * spring_up_dir
		
		contact = ray.wheel.global_position
		var force_pos_offset := contact - global_position
		apply_force(force_vector, force_pos_offset)
		
		DebugDraw3D.draw_arrow_ray(contact, force_vector/mass, 2, Color.LIME_GREEN, 0.1)
