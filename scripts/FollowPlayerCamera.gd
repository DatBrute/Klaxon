extends Camera2D

@onready var G = $"/root/Globals"

func _ready():
	zoom.x = G.MIN_ZOOM
	zoom.y = G.MIN_ZOOM
	G.player_camera = self
	if self.current:
		G.current_camera = self

func _process(_delta):
	if self.current:
		G.current_camera = self
