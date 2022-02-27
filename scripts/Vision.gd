# used solely for the vision shader

extends ColorRect
@onready var G = $"/root/Globals"
var positions = [];
var visuals = [];
var radars = [];

func _ready():
	for i in range(1024):
		positions.append(Vector2.ZERO)
		visuals.append(0.0)
		radars.append(0.0)
	material.set_shader_param("global_transform", get_global_transform())
	material.set_shader_param("radar_falloff", G.radar_falloff)

func _process(_delta):
	var team = G.client_vision_team
	if(team == -1):
		material.set_shader_param("see_all", true)
		return
	
	var units = get_tree().get_nodes_in_group("Unit")
	
	var array_length = 0
	for i in range(units.size()):
		if (units[array_length].team == team):
			positions[i] = units[array_length].global_position
			radars[i] = units[array_length].radar_strength
			visuals[i] = units[array_length].visual_range
			array_length += 1
			assert(array_length < 1025, "There must not be more than 1024 units on a team due to shader limitation")
	material.set_shader_param("see_all", false)
	material.set_shader_param ("positions", positions)
	material.set_shader_param ("radars", radars)
	material.set_shader_param ("visuals", visuals)
	material.set_shader_param("array_length", array_length)
