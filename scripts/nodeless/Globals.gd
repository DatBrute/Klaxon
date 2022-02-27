# global variables which all units need access to

extends Node

const ewar_regen_mult = 1.0
const radar_falloff = 0.002 # in loss per pixel
const max_radar_MTTH = 30
const min_radar_MTTH = 5

@onready var pfps = ProjectSettings.get_setting("physics/common/physics_fps")
@onready var pdelta = 1.0/pfps
var player_camera = null
var free_camera = null
var current_camera = null
var players = [null, null]
enum Roll {LEFT = 0, STRAIGHT = 1, RIGHT = 2, GUIDED = 3}
func roll_to_int(roll):
	assert(roll in [Roll.LEFT, Roll.STRAIGHT, Roll.RIGHT])
	return (-1 if roll == Roll.LEFT
	else 0 if roll == Roll.STRAIGHT
	else 1) # if roll == Roll.RIGHT

var client_vision_team = 0
# -1 means show everything, positive numbers mean show only what that team's units see
var visible_units
var team_count = 2
func get_visible_units(team = client_vision_team):
	var units =  get_tree().get_nodes_in_group("Unit")
	if client_vision_team == -1:
		return units
	var ret = []
	for ally in units:
		if(ally.team == team):
			if(not (ally in ret)):
				ret.append(ally)
			for enemy in units:
				if(enemy.team != team and not (enemy in ret)):
					if(enemy in ally.tracked_enemies): 
						ret.append(enemy)
	return ret

# MTTH = Mean Time To Happen, a term from Paradox. 
# returns chance per tick as a decimal between 0 and 1
func MTTH_to_chance(mtth, delta):
	return 1 / (mtth / delta)

func _ready():
	process_priority = -100

func _physics_process(_delta):
	visible_units = []
	for i in range(0, team_count):
		visible_units.append(get_visible_units(i))
