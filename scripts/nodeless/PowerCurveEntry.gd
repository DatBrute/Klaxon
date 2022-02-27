# script which defines the PowerCurveEntry data object
# used for managing speed, turnrate, and other turn-related derived values

var speed : float
var r_rate # radians per second, 0 = does not turn
var r_time  # time to 360, -1 = does not turn
var r_radius
var r_circumference : float



# PowerCurveEntry.new(speed, r_time)
func _init(new_speed, new_r_time):
	self.speed = new_speed
	set_time(new_r_time)


func set_rate(x):
	r_rate = x
	r_time = (2.0*PI) / x if r_rate != 0 else -1
	r_circumference = r_time * speed
	r_radius = r_circumference / (2.0*PI)
#	print(speed, ",    ", r_rate, ",    ", r_time, ",    ", r_circumference, ",    ", r_radius)

func set_time(time):
	set_rate ((2.0*PI) / time if time != -1 else 0)
	
func set_circumference(circumference):
	set_time(circumference / speed if speed != 0 else -1)
	
func set_radius(radius):
	set_circumference(radius * (2.0*PI))


func interpolate_by_speed(new_speed, other_power):
	# assert speed < new_speed < other_power.speed
	assert (speed <= new_speed and new_speed <= other_power.speed)
	# amount = difference / max_difference
	var max_difference = other_power.speed - self.speed
	var difference = new_speed - self.speed
	var amount = 1.0 if max_difference == 0 else difference / max_difference
	assert (amount <= 1.0)
	var new_r_rate = lerp(self.r_rate, other_power.r_rate, amount)
	return self.get_script().new(new_speed, (2.0*PI)/new_r_rate)
