# monolith for all game objects, ctrl-f for "## SECTION"

extends CharacterBody2D

## SECTION DEFINITIONS

# in thise node specifically set on _enter_tree(), which is before _ready() and before all nodes are in the tree
# this way it can be used onready
var G 
const PCE = preload("nodeless/PowerCurveEntry.gd")

@export var team = 0
func get_enemy_team():
	return 0 if team == 1 else 1

enum Controller {PLAYER = 0, DUMB = 1, PURSUE_NEAREST = 1001, PURSUE_PLAYER = 1002}
@export var controller : Controller = Controller.DUMB
var is_player # set on _enter_tree(), which is before _ready() and before all nodes are in the tree

func set_controller(x):
	controller = x
	is_player = x == Controller.PLAYER
	if(is_player):
		assert(G.players[team] == null or G.players[team] == self, "The player unit must not be changed")
		G.players[team] = self
		$"/root/World/UI/Bars".set_unit(self)


# may be position node or vector, use get_target_pos() to access position/node as position
# set on _ready()
var target = null

func is_pursuit():
	return controller in [Controller.PURSUE_NEAREST, Controller.PURSUE_PLAYER]
	

enum CollisionTags {AIR = 11, GROUND = 12}
var CollisionTagValues = [11, 12] # hopefully a temporary measure for 4.0
@export var collision_tags = []
func set_collision_tags(x):
	for tag in CollisionTagValues:
		set_collision_layer_value(tag, tag in x)
	collision_tags = x
@export var target_collision_tags = []
func set_target_collision_tags(x):
	for tag in CollisionTagValues:
		$ExplosionArea.set_collision_mask_value(tag, tag in x)
	target_collision_tags = x

#@export var collision_line_color = Color.RED
#@export var collision_line_width = 1.0
#@export var _collision_poly_color = Color(1, 0, 0, 0.25)
#var collision_poly_color = PackedColorArray([_collision_poly_color])
@export var trail_length = 0
@export var  trail_width = 0
@export var trail_color = Color.GRAY
@export var orbit_size =  0
@export var orbit_color = Color.GRAY
@onready var collision_draw_points = $CollisionPolygon2D.polygon
#@export var draw_collision = true
@export var draw_explosion_prediction = false
@export var explosion_prediction_ring_color = Color.BLUE
@export var explosion_prediction_circle_color = Color(0, 0, 1, 0.25)
@export var explosion_prediction_ring_width = 1.0

@export var acceleration = 100
@export var deceleration = 100
@export var max_fuel = -1.0
@onready var fuel = max_fuel

@export var max_health = -1
@onready var health = max_health
@export var explosion_radius = 0
func set_explosion_radius(x : int):
	$ExplosionArea/Collision.shape.radius = x
	explosion_radius = x
@export var auto_detonate = false

var dying = false
@onready var sprite = $Sprite2D


# purely for @export/init, built into the below variable then never used
# [speed, turntime]
@export var _power_curve = [[0, -1],[250, 4],[500, 3],[1000, 0.1]]
# array of PCEs constructed from the above
var power_curve = []
# array of PCEs constructed from the above and the evasive_r_rate_cap
var capped_power_curve = []
var pce : PCE # current speed and turn data
@export var speed = 0

var course_altered = false


var roll = 0.0
var guided = false
func guide(to_guided, to_target = null):
	guided = to_guided
	target = to_target
	roll = 0
var trail = []



var tracked_enemies = []
var tracking_enemies = [] # enemies that are tracking us
@export var is_decoy = false # always visible, and instantly destroyed when detected




@export var visual_range : float = 0.0 # instant detection
var evasive_action = true
@export var evasive_r_rate_cap = -1.0
@export var max_ewar = 30.0 # in seconds of evasive action
@onready var ewar = max_ewar
@export var radar_strength = 2.0 # >= 1 is full strength, but higher values help with falloff
#@export var offensive_jam_strength = 1 # in ewar loss per second, times radar_strength percentage if <100%
#@export var defensive_jam_strength = 10 # in flat ewar negation


var is_ammo # set on ready
var auto_groups = ["Unit"]


## SECTION OVERRIDES

func _enter_tree():
	G = $"/root/Globals"
	set_controller(controller)


func _ready():
	var time_cap = 360/evasive_r_rate_cap
	for pair in _power_curve:
		var _speed = pair[0]
		var time = pair[1]
		
		var _pce = PCE.new(_speed, time)
		power_curve.append(_pce)
		
		if(time > 0 and evasive_r_rate_cap > 0 and time_cap > time):
			time = max(time, time_cap)
		var capped_pce = PCE.new(_speed, time)
		capped_power_curve.append(capped_pce)
	set_speed(speed)
	set_collision_tags(collision_tags)
	set_target_collision_tags(target_collision_tags)
	set_explosion_radius(explosion_radius)
	$ExplosionArea.add_child($CollisionPolygon2D.duplicate())
	if get_parent() == get_tree().get_root():
		is_ammo = false
	else:
		var script = get_parent().get_script()
		is_ammo = script != null and script.get_path().get_file() == "Gun.gd"
	if(is_ammo):
		assert(get_parent().get_parent().team == team, "Guns must not fire units of different teams.")
	for group in auto_groups:
		add_to_group(group)

func _physics_process(delta):
	match(controller):
		Controller.PLAYER:
			guide(false)
			if !$"/root/World".cli_activated:
				if Input.is_action_just_pressed('evasive_action_toggle'):
					evasive_action = not evasive_action
				if Input.is_action_pressed('accelerate'):
					set_speed(speed + acceleration * delta)
					course_altered = true
					target = null
				elif Input.is_action_pressed('decelerate'):
					set_speed(speed - deceleration * delta)
					course_altered = true
					target = null
				elif Input.is_action_just_pressed('evasive_action_toggle'):
					set_speed(speed)
				if Input.is_action_pressed('turn_left'):
					roll = -1.0
					course_altered = true
					target = null
				elif Input.is_action_pressed('turn_right'):
					roll = 1.0
					course_altered = true
					target = null
				else:
					roll = 0.0
		Controller.DUMB:
			guide(false)
		Controller.PURSUE_NEAREST:
			var nearest = null
			var nearest_dist = null
			for unit in get_tree().get_nodes_in_group('Unit'):
				if unit.team != team:
					if(nearest == null):
						nearest = unit
						nearest_dist = unit.global_position.distance_to(global_position)
					else:
						var dist = unit.global_position.distance_to(global_position)
						if (dist < nearest_dist):
							nearest = unit
							nearest_dist = dist
			guide(true, nearest)
		Controller.PURSUE_PLAYER:
			guide(true, G.players[get_enemy_team()])

	if(evasive_action):
		ewar = max(ewar - delta, 0)
	else:
		ewar = min(ewar + delta * G.ewar_regen_mult, max_ewar)
	
	var move = calculate_movement(delta)
		
	global_position = move[0]
	rotation += move[1]
	
	update_tracked_enemies(delta)
	
	if(max_fuel >= 0):
		fuel = fuel - min(speed*delta, fuel)
		assert(fuel >= 0, "Remaining fuel must be positive at all times")
		if fuel == 0 or (targets_in_explosion_range().size() > 0 and auto_detonate):
			die(auto_detonate)
			return
	
	
	if(trail_length > 0):
		trail.append(global_position)
		if(trail.size() > trail_length):
			trail.pop_front()
	
	if(controller == Controller.PLAYER):
		var time_string = "none" if pce.r_time < 0 else "%.1f" % pce.r_time
		$"/root/World/UI/BottomText".text = \
			("speed: %.0f time: %s radius: %.0f, deg/sec: %.0f%s" % \
			[speed, time_string, pce.r_radius, rad2deg(pce.r_rate), ", E" if evasive_action else ""])	
		
	course_altered = false

func _process(_delta):
	update()

func _draw():
	if not is_visible_by_team(G.client_vision_team):
		return
#	if(draw_collision and collision_draw_points.size() > 0):
#		var to_draw = collision_draw_points + PackedVector2Array([collision_draw_points[0]])
#		draw_polyline(to_draw, collision_line_color, collision_line_width)
#		draw_polygon(to_draw, collision_poly_color)

	if trail_length > 0 and trail.size() >= 2:
		var trail_draw = []
		for point in trail:
			trail_draw.append(to_local(point))
			pass
		draw_polyline(trail_draw, trail_color, trail_width)

	if(roll != null and roll != 0 and pce.r_radius > 0 and orbit_size > 0):
		draw_circle(get_orbit(roll), orbit_size, orbit_color)
	
	if(draw_explosion_prediction and (not dying) and (speed != 0) and (max_fuel > 0.0)):
			var explosion_prediction_pos = to_local(calculate_movement(fuel/speed)[0])
			var max_radius = $ExplosionArea/Collision.shape.radius
			var mult = 1.0 - (fuel / max_fuel)
			var radius = max_radius * mult
			if(radius > 0.0):
				draw_circle(explosion_prediction_pos, radius,
					explosion_prediction_circle_color)
				draw_arc(explosion_prediction_pos, $ExplosionArea/Collision.shape.radius, 0, 2*PI, 32, 
				explosion_prediction_ring_color, explosion_prediction_ring_width)
	
#	if(tracking_enemies != []):
#		draw_circle(Vector2(500,0), 5, Color.red)
#
#	draw_circle(Vector2(0, 0), 500, Color(0,0,0,0.1))
#	draw_circle(Vector2(0, 0), 250, Color(0,0,0,0.2))
	

func _input(event):
	if(controller == Controller.PLAYER):
		if event.is_action_pressed("l_click"):
			target = get_global_mouse_position()
		if event.is_action_pressed("r_click"):
			target = get_global_mouse_position() - global_position

## SECTION MOVEMENT

func max_speed():
	var pc = power_curve if evasive_action else capped_power_curve
	return pc[pc.size()-1].speed

func min_speed():
	return power_curve[0].speed # we don't need capped_power_curve here

func set_speed(x):
	var pc = power_curve if evasive_action else capped_power_curve
	if (pc == []):
		speed = x
		return
	x = clamp(x, min_speed(), max_speed())
	speed = x
	if(pc[0].speed >= x):
		pce = pc[0]
		return
	for i in range(1, pc.size()):
		if pc[i].speed >= x:
			pce = pc[i-1].interpolate_by_speed(x, pc[i])
			return
	print("This line should never be reached!")
	get_tree().quit()
	

# the point that this unit will orbit around if untouched
func get_orbit(_roll = roll) -> Vector2:
	return Vector2(0, calc_orbit_radius(_roll) * (-1 if _roll < 1 else 1))

func calc_orbit_radius(_roll = roll):
	return abs(pce.r_radius * _roll)

## SECTION DEATH

func die(explode = true):
	if controller == Controller.PLAYER:
		$"/root/World/UI/BottomText".text = "You are dead."
	if explode:
		var targets = targets_in_explosion_range()
		print("%s is exploding, " % self
			+ ("hitting no targets." if targets == [] 
			else "hitting these targets: %s." % targets))
	else:
#		print("%s is dying peacefully" % self)
		pass
	var death = get_node_or_null("DeathAnim")
	if death != null:
		set_physics_process(false)
		collision_draw_points = []
		death.visible = true
		death.playing = true
		dying = true
		if(sprite != null):
			sprite.visible = false
		for x in collision_tags:
			set_collision_layer_value(x, false)
		for x in target_collision_tags:
			set_collision_mask_value(x, false)
	else:
		queue_free()
	

# targets in range of the explosion triggering on unit's death
func targets_in_explosion_range():
	var ret = $ExplosionArea.get_overlapping_bodies() 
	var x = ret.find(self)
	if(x != -1):
		ret.remove(x)
	return ret

func _on_DeathAnim_animation_finished():
	queue_free()
	


## SECTION VISION

func update_tracked_enemies(delta):
	for enemy in tracked_enemies:
		if chance_to_see(enemy, delta) == 0:
			tracked_enemies.erase(enemy)
			enemy.tracking_enemies.erase(self)
	var units =  get_tree().get_nodes_in_group("Unit")
	for enemy in units:
		if(enemy.team != team and not (enemy in tracked_enemies)):
			if(randf() <= chance_to_see(enemy, delta)):
				if(enemy.is_decoy):
					enemy.die(false)
				else:
					tracked_enemies.append(enemy)
					enemy.tracking_enemies.append(self)


func chance_to_see(enemy, delta):
	var dist = enemy.global_position.distance_to(global_position)

	if (dist <= visual_range):
		return 1.0
	
	var strength = clamp((radar_strength - (dist * G.radar_falloff)), 0.0, 1.0)
	return G.MTTH_to_chance(lerp(G.max_radar_MTTH, G.min_radar_MTTH, strength), delta)
	
func is_visible_by_team(vision_team):
	return true if (vision_team == team or vision_team == -1 or is_decoy) \
		else (self in G.visible_units[vision_team])
	

## SECTION AI

# used for calculating circular movement and not just prediction for the user
# list of locals: speed, global_position
# list of vars: delta, roll
# list of var-derived: fuel, orbit_radius, orbit
# returns [final global position, rotation]
func calculate_movement(delta):
	var move = speed*delta if max_fuel < 0 else min(fuel, speed*delta)
	if (!guided and roll == 0) or pce.r_rate == 0:
		return [global_position + Vector2(move, 0.0).rotated(rotation), 0.0]
	if guided:
		roll = clamp(get_angle_to(get_target_pos()) / (pce.r_rate * delta), -1, 1)
	var r_rate = pce.r_rate
	var rot = r_rate * roll * delta
	var orbit_radius = calc_orbit_radius(roll)
	if speed != 0 and roll == 1 or roll == -1:
		print(orbit_radius)
		var orbit = to_global(get_orbit(roll))
		var angle_add = 2.0 * PI * roll * move / pce.r_circumference
		print(angle_add)
		var current_angle = (global_position - orbit).angle()
#		var current_pos = orbit + Vector2.RIGHT.rotated(current_angle) * orbit_radius
		var final_angle = current_angle + angle_add
		var final_pos = orbit + Vector2.RIGHT.rotated(final_angle) * orbit_radius
		return [final_pos, rot]	
	else:
		return [global_position + Vector2(move, 0.0).rotated(rotation), rot]

func get_target_pos():
	return target.global_position if target is Node else target
