# global variables which all units need access to

extends Node

const ZOOM_SPEED = 50
const MIN_ZOOM = 0.25 # lower zoom = more zoomed in
const MAX_ZOOM = 1 
const PAN_SPEED = 100

const EWAR_REGEN_MULT = 1.0
const RADAR_FALLOFF = 0.002 # in loss per pixel
const MAX_RADAR_MTTH = 30
const MIN_RADAR_MTTH = 5

@onready var pfps = ProjectSettings.get_setting("physics/common/physics_fps")
@onready var pdelta = 1.0/pfps
var player_camera = null
var free_camera = null
var current_camera = null
var players = [null, null]

#var client_vision_team = 0
## -1 means show everything, positive numbers mean show only what that team's units see
#var visible_units
#var team_count = 2
#func get_visible_units(team = client_vision_team):
#	var units =  get_tree().get_nodes_in_group("Unit")
#	if client_vision_team == -1:
#		return units
#	var ret = []
#	for ally in units:
#		if(ally.team == team):
#			if(not (ally in ret)):
#				ret.append(ally)
#			for enemy in units:
#				if(enemy.team != team and not (enemy in ret)):
#					if(enemy in ally.tracked_enemies): 
#						ret.append(enemy)
#	return ret

# MTTH = Mean Time To Happen, a term from Paradox. 
# returns chance per tick as a decimal between 0 and 1
func MTTH_to_chance(mtth, delta):
	return 1 / (mtth / delta)

func _ready():
	process_priority = -100

#func _physics_process(_delta):
#	visible_units = []
#	for i in range(0, team_count):
#		visible_units.append(get_visible_units(i))
