shader_type spatial;
render_mode unshaded, cull_front, depth_draw_always;

uniform float outline_thickness = 2.0; // Thickness in pixels
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float alpha_multiplier = 0.0;
uniform vec2 shift_dir = vec2(0.0, 0.0);

void vertex() {
	vec4 clip_position = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);

	// Shift the entire mesh silhouette in a specific 2D direction.
	// We divide by VIEWPORT_SIZE to normalize pixel counts to -1..1 clip space coordinates
	// We multiply by clip_position.w to preserve the shift through the perspective divide
	vec2 offset_pixels = shift_dir * (outline_thickness / VIEWPORT_SIZE);
	clip_position.xy += offset_pixels * clip_position.w * 2.0;

	// Push back in depth so it draws strictly behind the main model
	clip_position.z += 0.005 * clip_position.w;

	POSITION = clip_position;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a * alpha_multiplier;
}
