extends Node3D
class_name DayNightCycle

@export var day_length_minutes: float = 10.0
@export var start_time_hours: float = 6.0 # Morning

@export var sun_color: Gradient
@export var sun_intensity: Curve
@export var moon_color: Gradient
@export var moon_intensity: Curve

@export var sky_top_color: Gradient
@export var sky_horizon_color: Gradient

@export var ambient_color: Gradient
@export var fog_color: Gradient

@onready var sun: DirectionalLight3D = $Sun
@onready var moon: DirectionalLight3D = $Moon
@onready var environment: WorldEnvironment = $WorldEnvironment

var time: float = 0.0

func _ready():
	time = start_time_hours / 24.0
	_update_time_of_day()

func _process(delta):
	var day_length_seconds = day_length_minutes * 60.0
	var time_increment = delta / day_length_seconds
	time += time_increment

	if time >= 1.0:
		time -= 1.0

	_update_time_of_day()

func _update_time_of_day():
	# Update Sun and Moon rotation
	# At time = 0.25 (6am), sun_angle = 0 (horizon)
	# At time = 0.50 (noon), sun_angle = -PI/2 (overhead)
	# At time = 0.75 (6pm), sun_angle = -PI (horizon)
	var sun_angle = time * -TAU + (PI / 2.0)
	sun.rotation.x = sun_angle
	moon.rotation.x = sun_angle + PI

	# Update Light Colors and Intensities
	if sun_color and sun_intensity:
		sun.light_color = sun_color.sample(time)
		sun.light_energy = sun_intensity.sample(time)

	if moon_color and moon_intensity:
		moon.light_color = moon_color.sample(time)
		moon.light_energy = moon_intensity.sample(time)

	# Update Environment Colors
	if environment and environment.environment:
		var env = environment.environment
		if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
			var sky_mat = env.sky.sky_material as ProceduralSkyMaterial
			if sky_top_color:
				sky_mat.sky_top_color = sky_top_color.sample(time)
			if sky_horizon_color:
				sky_mat.sky_horizon_color = sky_horizon_color.sample(time)

		if ambient_color:
			env.ambient_light_color = ambient_color.sample(time)

		if fog_color:
			env.fog_light_color = fog_color.sample(time)
