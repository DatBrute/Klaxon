shader_type canvas_item;

uniform vec2 positions[1024];
uniform float radars[1024]; // range = this/radar_falloff
uniform float visuals[1024]; // range = this
uniform int array_length = 0;

uniform float RADAR_FALLOFF = 0;


const vec3 visual_color = vec3(0.67, 0.67, 0.6);  
const vec3 high_radar_color = vec3(0.62, 0.62, 0.55);  
const vec3 medium_radar_color = vec3(0.57, 0.57, 0.5);  
const vec3 low_radar_color = vec3(0.52, 0.52, 0.45);

uniform mat4 global_transform;
varying vec2 world_position;


void vertex(){
	world_position = (global_transform * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment(){
	float strength = 0.0;
	bool visual = false;
	for(int i = 0; (i < array_length) && (!visual); i += 1){
		float dist = distance(world_position, positions[i]);
		if(dist <= visuals[i]){
			visual = true;
		}else{
			float to_strength = clamp((radars[i] - (dist * RADAR_FALLOFF)), 0.0, 1.0);
			if(to_strength > 0.0){
				strength = max(strength, to_strength);
			}
		}
	}
	COLOR.rgb =
		visual ? visual_color :
		(strength >= 1.0 ? high_radar_color : 
		(strength >= 0.5 ? medium_radar_color :
		(strength > 0.0 ? low_radar_color :
		COLOR.rgb)));
}