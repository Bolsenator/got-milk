shader_type canvas_item;

/* ================= SETTINGS ================= */
// Pixel size to match your art scale
uniform float pixel_size = 0.25;
// Edge glow color
uniform vec4 glow_color : source_color = vec4(0.5, 0.0, 1.0, 1.0);
// Brightness of the glow
uniform float glow_intensity = 1.2;
// Speed of the glow pulse
uniform float glow_pulse_speed = 2.0;

/* ================= FRAGMENT SHADER ================= */
void fragment() {
    // Quantize UV to pixel grid
    vec2 texture_size = 1.0 / TEXTURE_PIXEL_SIZE;
    vec2 uv = floor(UV * texture_size / pixel_size) * pixel_size / texture_size;
    vec2 base_uv = uv;

    // Sample base texture
    vec4 base = texture(TEXTURE, uv);
    vec3 color = base.rgb;

    /* ----- EDGE GLOW ----- */
    vec2 ps = TEXTURE_PIXEL_SIZE * pixel_size;
    float n = texture(TEXTURE, base_uv + vec2(0.0, -ps.y)).a;
    float s = texture(TEXTURE, base_uv + vec2(0.0, ps.y)).a;
    float e = texture(TEXTURE, base_uv + vec2(ps.x, 0.0)).a;
    float w = texture(TEXTURE, base_uv + vec2(-ps.x, 0.0)).a;
    float edge = (1.0 - base.a) * max(max(n, s), max(e, w));
    float pulse = (sin(TIME * glow_pulse_speed) * 0.5 + 0.5);
    float glow_alpha = edge * glow_intensity * pulse;
    vec3 final_color = mix(color, glow_color.rgb, glow_alpha);
    float final_alpha = max(base.a, glow_alpha);

    COLOR = vec4(final_color, final_alpha);
}