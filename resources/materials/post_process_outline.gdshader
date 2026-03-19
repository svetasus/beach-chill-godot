shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0);
uniform float outline_thickness : hint_range(1.0, 10.0, 0.1) = 3.0;
uniform float alpha_multiplier = 0.0;

void fragment() {
    // TEXTURE is automatically populated by the SubViewportContainer
    // UV maps perfectly to the entire screen
    vec4 current_color = texture(TEXTURE, UV);

    // If the pixel is already solid in the sub-viewport (the actual object),
    // we don't draw the outline *over* it. We want a rim around it.
    if (current_color.a > 0.1) {
        COLOR = vec4(0.0);
        return;
    }

    // Check neighbors to see if we are on an edge
    vec2 pixel_size = 1.0 / vec2(textureSize(TEXTURE, 0));
    float max_alpha = 0.0;

    for (float y = -outline_thickness; y <= outline_thickness; y += 1.0) {
        for (float x = -outline_thickness; x <= outline_thickness; x += 1.0) {
            // Circle check makes corners perfectly round
            if (length(vec2(x, y)) <= outline_thickness) {
                vec2 uv_offset = vec2(x, y) * pixel_size;
                vec4 neighbor_color = texture(TEXTURE, UV + uv_offset);
                max_alpha = max(max_alpha, neighbor_color.a);
            }
        }
    }

    if (max_alpha > 0.1) {
        COLOR = outline_color;
        COLOR.a *= alpha_multiplier;
    } else {
        COLOR = vec4(0.0);
    }
}
