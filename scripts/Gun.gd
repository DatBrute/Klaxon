# child node of a unit, which activates on command or under AI triggers
# the activation behavior is always to spawn one or more units

extends Node2D

@onready var G = $"/root/Globals"
# Projectiles must have the load as placeholder box checked and placed 1 per gun. 
# They can be fired any number of times, with any custom attributes! Transform is on the gun.

# some successfully tested items: single click burst, overflow, cancelling, does_ai_want_to_fire()
 
enum Keys {NOTHING = -1, ONE=49, TWO=50, THREE=51, FOUR=52, FIVE=53}
@export var fire_key : Keys = Keys.ONE
@export var clip_reload = 5.0
@export var bullets_per_second = 5.0
@onready var shot_reload = 1/bullets_per_second
@export var max_ammo = -1 # -1 = infinite
@export var single_click_for_full_burst = false
@export var ai_min_fire_range = 0.0
@export var ai_max_fire_range = 0.0
@export var ai_max_fire_angle_degrees = 0.0

var current_warmup : float = 0.0
var current_shot_reload : float = 0.0
var current_clip_reload : float = 0.0
@onready var current_ammo : int = max_ammo
var full_burst : bool = false

func _ready():
	
	assert (not (single_click_for_full_burst and max_ammo == -1), \
		"A single click must not fire a burst of infinite length")	
	assert(get_child_count() == 1, "Guns must have exactly one child.")
	var child = get_child(0)
	assert(child is InstancePlaceholder, \
		"The child of a Gun must be an InstancePlaceholder of the Unit class. Right-click -> Load as Placeholder.")
	child.team = get_parent().team

func _physics_process(delta):
	if(current_ammo == 0 and max_ammo != -1):
		reload_clip(delta)
	elif(current_shot_reload > 0):
		reload_shot(delta)
	elif (get_parent().is_player):
		if(single_click_for_full_burst):
			if(Input.is_key_pressed(fire_key)):
				full_burst = true
			if(full_burst):
				fire(delta)
			else:
				reload_clip(delta)
		elif(Input.is_key_pressed(fire_key)):
			fire(delta)
		else:
			reload_clip(delta)
	elif(does_ai_want_to_fire()):
			fire(delta)
	else:
			reload_clip(delta)

# Team Fortress 2 style reloading, auto and can be cancelled anytime if our clip is not empty
func reload_clip(delta):
	if(current_ammo == 0):
		full_burst = false  # our volley is over, wait for next click to repeat
	current_clip_reload += delta
	if(current_clip_reload >= clip_reload):
		current_clip_reload = 0
		current_ammo = max_ammo

func reload_shot(delta):
	current_clip_reload = 0
	current_shot_reload += delta
	if(current_shot_reload >= shot_reload):
		var to_reload_clip = current_shot_reload - shot_reload
		current_shot_reload = 0
		# spend extra time reloading. PFPS is an integer so this should usually be neglible, but why not
		reload_clip(to_reload_clip) 


	
func does_ai_want_to_fire():
	var enemy_player = G.players[0 if get_parent().team != 0 else 1]
	var enemy_range =  self.global_position.distance_to(enemy_player.global_position)
	var enemy_angle = rad2deg(abs(global_position.direction_to(enemy_player.global_position).angle()))
	return enemy_range >= ai_min_fire_range \
		and enemy_range <= ai_max_fire_range \
		and enemy_angle <= ai_max_fire_angle_degrees

func fire(delta):
	current_ammo -= 1
	current_clip_reload = 0
	var only_child = self.get_child(0)
	var instance = only_child.create_instance()
	instance.transform = self.global_transform
	self.remove_child(instance)
	$"/root/World".add_child(instance)
	reload_shot(delta)
