shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.28;
uniform float tint_strength : hint_range(0.0, 1.0) = 0.12;
uniform vec4 tint_color : source_color = vec4(0.45, 0.62, 0.95, 1.0);
uniform float enabled : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float aspect = SCREEN_PIXEL_SIZE.y / max(SCREEN_PIXEL_SIZE.x, 0.0001);
	vec2 centered = uv - vec2(0.5);
	centered.x *= aspect;
	float dist = length(centered) * 1.35;
	float vig = smoothstep(0.25, 1.05, dist) * vignette_strength * enabled;
	vec3 tint = mix(vec3(1.0), tint_color.rgb, tint_strength * enabled);
	COLOR = vec4(tint, vig);
}
