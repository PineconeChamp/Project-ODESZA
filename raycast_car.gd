extends RigidBody3D

@export var wheels: Array[RaycastWheel]
@export var acceleration := 4000.0

# Temporary as I will implement gearing and possibly simulated torque
@export var max_speed := 30
@export var accel_curve : Curve
@export var tire_turn_speed := 2.0
@export var tire_max_turn_degrees:= 25.0

var motor_input := 0.0
var handbrake := 0.0

func _unhandled_input(event: InputEvent) -> void:
	
	if event.is_action_pressed("drift"):
		handbrake = 1.0
	elif event.is_action_released("drift"):
		handbrake = 0.0
	
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
		
func _basic_steering_rotation(delta: float) -> void:
	var turn_input := Input.get_axis("turn_right", "turn_left") * tire_turn_speed
	
	if turn_input:
		$"Wheel FL".rotation.y = clampf($"Wheel FL".rotation.y + turn_input * delta,
		deg_to_rad(-tire_max_turn_degrees), deg_to_rad(tire_max_turn_degrees))
		
		$"Wheel FR".rotation.y = clampf($"Wheel FR".rotation.y + turn_input * delta,
		deg_to_rad(-tire_max_turn_degrees), deg_to_rad(tire_max_turn_degrees))
	else:
		$"Wheel FL".rotation.y = move_toward($"Wheel FL".rotation.y, 0, tire_turn_speed * delta)
		$"Wheel FR".rotation.y = move_toward($"Wheel FR".rotation.y, 0, tire_turn_speed * delta)

func _physics_process(_delta: float) -> void:
	DebugDraw3D.draw_arrow_ray(global_position, linear_velocity, 2.5, Color.ALICE_BLUE, 0.1)
	_basic_steering_rotation(_delta)
	for wheel in wheels:
		wheel.force_raycast_update()
		_do_single_wheel_suspension(wheel)
		_do_single_wheel_acceleration(wheel)
		_do_single_wheel_traction(wheel)


func _get_point_velocity(point: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - global_position)
	
	
func _do_single_wheel_traction(ray: RaycastWheel) -> void:
	if not ray.is_colliding(): return
	
	var steer_side_dir := ray.global_basis.x
	var tire_vel := _get_point_velocity(ray.wheel.global_position)
	var steering_x_vel := steer_side_dir.dot(tire_vel)
	
	var grip_factor := absf(steering_x_vel/tire_vel.length())
	var x_traction := ray.grip_curve.sample_baked(grip_factor)
	
	if handbrake != 0:
		x_traction = 0.1
	
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var x_force := -steer_side_dir * steering_x_vel * x_traction * ((mass*gravity)/4.0)
	
	# z force traction
	var f_vel := -ray.global_basis.z.dot(tire_vel)
	var z_traction := 0.05
	var z_force := ray.global_basis.z * f_vel * z_traction * ((mass*gravity)/4.0)
	
	var force_pos := ray.wheel.global_position - global_position
	apply_force(x_force, force_pos)
	apply_force(z_force, force_pos)
	DebugDraw3D.draw_arrow(ray.wheel.global_position, x_force/mass*2, Color.ORANGE, 0.1)
	DebugDraw3D.draw_arrow(ray.wheel.global_position, z_force/mass*2, Color.YELLOW, 0.1)
	
	# A more realistic aproach
	# F = M * A
	# F = M * dV/T
	#var desired_accel := (steering_x_vel * x_traction) / get_physics_process_delta_time()
	#var x_force := -steer_side_dir * desired_accel * (mass/4.0)
	
	
	
	
func _do_single_wheel_acceleration(ray: RaycastWheel) -> void:
	var forward_dir := -ray.global_basis.z
	var vel := forward_dir.dot(linear_velocity)
	ray.wheel.rotate_x((-vel * get_process_delta_time()) / ray.wheel_radius)
	
	if ray.is_colliding():
		
		var contact := ray.wheel.global_position
		var force_pos := contact - global_position
		print(motor_input)
		print(forward_dir*acceleration)
		
		if ray.is_motor and motor_input != 0:
			var speed_ratio := vel / max_speed
			var ac := accel_curve.sample_baked(speed_ratio)
			var force_vector := forward_dir * acceleration * motor_input * ac
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
		
		var force_vector := (spring_force - spring_damp_force) * ray.get_collision_normal()
		
		contact = ray.wheel.global_position
		var force_pos_offset := contact - global_position
		apply_force(force_vector, force_pos_offset)
		
		DebugDraw3D.draw_arrow_ray(contact, force_vector/mass, 2, Color.LIME_GREEN, 0.1)
