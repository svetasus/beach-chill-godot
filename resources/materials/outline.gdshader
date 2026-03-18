shader_type spatial;
render_mode unshaded, cull_front, depth_draw_always;

uniform float outline_thickness = 3.0; // Thickness in pixels
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float alpha_multiplier = 0.0;

void vertex() {
	// 1. Transform vertex to clip space
	vec4 clip_position = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);

	// 2. Transform normal to view space, then to clip space
	vec3 view_normal = normalize(mat3(MODELVIEW_MATRIX) * NORMAL);
	vec4 clip_normal = PROJECTION_MATRIX * vec4(view_normal, 0.0);

	// 3. Normalize the 2D clip normal to get the expansion direction
	vec2 offset_dir = normalize(clip_normal.xy);

	// 4. Aspect ratio correction so the outline is round, not stretched
	float aspect = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	offset_dir.x *= aspect;

	// 5. Convert the desired pixel thickness to clip space coordinates (-1 to 1)
	// We divide by VIEWPORT_SIZE.y to get the fraction of the screen height
	vec2 offset_pixels = offset_dir * (outline_thickness / VIEWPORT_SIZE.y) * 2.0;

	// 6. Apply perspective (w) so the thickness remains constant in pixels on screen
	clip_position.xy += offset_pixels * clip_position.w;

	// 7. Push the outline slightly backwards in depth (Z buffer)
	// This prevents the outline from clipping through the front of the model
	// and fixes the "before the model" issue.
	clip_position.z += 0.0005 * clip_position.w;

	POSITION = clip_position;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a * alpha_multiplier;
}
