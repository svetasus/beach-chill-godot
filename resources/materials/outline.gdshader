shader_type spatial;
render_mode cull_front, unshaded, depth_draw_always;

uniform vec4 outline_color : source_color;
uniform float outline_width = 3.0;

void vertex() {
	// 1. Transform vertex to clip space
	vec4 clip_position = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);

	// 2. Transform the object's origin (center) to clip space
	vec4 center_clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);

	// 3. Find the 2D direction from the center to the vertex on the screen
	// We ignore the actual mesh normals entirely to prevent faces from splitting at hard edges.
	vec2 offset_dir = normalize(clip_position.xy - center_clip.xy);

	// 4. Aspect ratio correction so the outline expands equally horizontally and vertically
	float aspect = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	offset_dir.x *= aspect;

	// 5. Calculate the outline size in clip space (-1 to 1)
	// We divide by VIEWPORT_SIZE.y to make the width exactly `outline_width` pixels
	vec2 offset = offset_dir * (outline_width / VIEWPORT_SIZE.y) * 2.0;

	// Apply the offset (multiply by .w to ensure it remains a constant pixel size regardless of distance)
	clip_position.xy += offset * clip_position.w;

	// Push slightly back in depth so it draws correctly behind the model
	clip_position.z += 0.005 * clip_position.w;

	POSITION = clip_position;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	if (outline_color.a < 1.0) {
		ALPHA = outline_color.a;
	}
}
