# Node responsible for some camera functions and the CLI

extends Node2D



var cli_activated = false
@onready var G = $"/root/Globals"

func camera_input(delta, c):
	var pan = G.PAN_SPEED * c.zoom.x * delta
	var zoom = G.ZOOM_SPEED * delta
	if(c != G.player_camera):
		if Input.is_action_pressed("pan_left"):
			c.position.x -= pan
		if Input.is_action_pressed('pan_right'):
			c.position.x += pan
		if Input.is_action_pressed("pan_up"):
			c.position.y -= pan
		if Input.is_action_pressed("pan_down"):
			c.position.y += pan
	if Input.is_action_just_released('zoom_in'):
		_zoom(zoom, c)
	if Input.is_action_just_released('zoom_out'):
		_zoom(-zoom, c)

func _zoom(i, c):
	c.zoom.x = clamp(c.zoom.x + i, G.MIN_ZOOM, G.MAX_ZOOM)
	c.zoom.y = clamp(c.zoom.y + i, G.MIN_ZOOM, G.MAX_ZOOM)
	

func _process(delta):
	var c = G.current_camera
	assert(c != null, "G must have a current camera.")
	if(c):
		camera_input(delta, c)

func _input(event):
	if event.is_action_pressed('toggle_cli'):
		toggle_console()
		get_viewport().set_input_as_handled()
	if (event.is_action_pressed("follow_player_toggle")):
		if(G.current_camera == G.free_camera):
			G.player_camera.current = true
			G.player_camera.zoom = G.current_camera.zoom
		else:
			assert(G.current_camera == G.player_camera, "Current_camera must be player_camera but is not.")
			G.free_camera.current = true
			G.free_camera.global_position = G.current_camera.global_position
			G.free_camera.zoom = G.current_camera.zoom
		

func toggle_console():
	if(cli_activated):
		cli_activated = false
		$UI/CLI.release_focus()
	else:
		cli_activated = true
		$UI/CLI.grab_focus()
