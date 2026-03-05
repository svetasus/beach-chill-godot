shader_type spatial;

// 1. COLORS & GRADIENT
uniform vec4 shallow_color : source_color = vec4(0.0, 1.0, 0.6, 0.8); // Emerald
uniform vec4 deep_color : source_color = vec4(0.0, 0.3, 0.8, 0.9);    // Blue
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float gradient_depth = 0.7; // How far until it turns blue

// 2. TEXTURES
uniform sampler2D noise_img;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture;

// 3. SETTINGS
uniform float wave_height = 0.2;
uniform float wave_speed = 1.0;
uniform float refraction_strength = 0.05;
uniform float foam_range = 0.2;
uniform float glow_intensity = 0.5; // Controls the "shimmer" brightness

void vertex() {
    // PHYSICAL WAVES (Kept from your current code)
    VERTEX.y += sin((TIME * wave_speed) + (VERTEX.x * 0.2) + (VERTEX.z * 0.2)) * wave_height;
}

void fragment() {
    // --- DEPTH CALCULATIONS ---
    float depth = texture(depth_texture, SCREEN_UV).r;
    vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
    vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
    view.xyz /= view.w;
    float linear_depth = -view.z;
    float water_depth = linear_depth + VERTEX.z;

    // --- RIPPLES & NOISE ---
    vec2 uv_offset1 = UV + (TIME * vec2(0.01, 0.01));
    vec2 uv_offset2 = UV + (TIME * vec2(-0.005, 0.01));
    float tex1 = texture(noise_img, uv_offset1).r;
    float tex2 = texture(noise_img, uv_offset2).r;
    float combined_noise = (tex1 + tex2) * 0.5;

    // --- REFRACTION ---
    vec2 refraction_offset = vec2(combined_noise) * refraction_strength;
    vec3 refraction_color = texture(screen_texture, SCREEN_UV + refraction_offset).rgb;


    // --- THE EMERALD GRADIENT ---
    // Mix Shallow Green and Deep Blue based on how deep the sand is


    // --- FOAM MASK ---
    float wavy_foam_range = foam_range + (combined_noise * 0.15);
    float foam_mask = clamp(1.0 - (water_depth / wavy_foam_range), 0.0, 1.0);
    foam_mask = pow(foam_mask, 2.0);

	float ripple_mask = smoothstep(0.0, 0.5, water_depth);
    // --- MIXING EVERYTHING ---
    // Mix distorted sand with our green/blue water base
    //vec3 water_with_refraction = mix(refraction_color, water_base, 0.6);

	float sharp_noise = pow(combined_noise, 3.0) * ripple_mask;

	float color_mix = clamp(water_depth / gradient_depth, 0.0, 1.0);
    vec3 water_base = mix(shallow_color.rgb, deep_color.rgb, color_mix);

    vec3 vivid_water = mix(water_base, vec3(1.0), sharp_noise * 0.5);

	float refraction_factor = mix(0.3, 0.7, color_mix);
    vec3 final_water = mix(refraction_color, vivid_water, refraction_factor);

    // Final Color: Refraction + Base Color + Foam on top
    ALBEDO = mix(final_water, foam_color.rgb, foam_mask);

    // --- THE GLOW (Emission) ---
    // This makes the noise ripples "shine" like they are radioactive
    EMISSION = (sharp_noise * glow_intensity) * water_base;

    ALPHA = mix(shallow_color.a, deep_color.a, color_mix) + foam_mask;
    ROUGHNESS = 0.1;
    SPECULAR = 1.0;
}