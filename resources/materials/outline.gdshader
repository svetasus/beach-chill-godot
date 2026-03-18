shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_opaque;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_thickness = 1.5; // Controls the sharpness of the rim
uniform float alpha_multiplier = 0.0;

void fragment() {
    // Calculate the Fresnel effect: 1.0 at edges, 0.0 at center
    float fresnel = 1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0);

    // Power function sharpens the edge, making it look like a thin outline
    fresnel = pow(fresnel, outline_thickness);

    // Apply color and fade
    ALBEDO = outline_color.rgb;
    ALPHA = fresnel * outline_color.a * alpha_multiplier;
}
