shader_type spatial;
render_mode unshaded, cull_front;

uniform float outline_thickness = 0.05;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float alpha_multiplier = 0.0;

void vertex() {
	// Extract the scale from the model matrix to normalize the thickness
	vec3 scale = vec3(
		length(MODEL_MATRIX[0].xyz),
		length(MODEL_MATRIX[1].xyz),
		length(MODEL_MATRIX[2].xyz)
	);

	// Divide the thickness by the scale so it's consistent in world space
	VERTEX += NORMAL * (outline_thickness / scale);
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a * alpha_multiplier;
}
