shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec2 cone_center = vec2(0.5, 0.5);
uniform vec2 cone_direction = vec2(1.0, 0.0);
uniform float cone_radius : hint_range(0.0, 1.5) = 0.35;
uniform float cone_angle : hint_range(0.0, 3.14159) = 0.85;
uniform vec4 darkness_color : source_color = vec4(0.0, 0.04, 0.02, 0.82);
uniform vec4 cone_color : source_color = vec4(0.25, 0.95, 0.4, 0.18);
uniform float intensity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 from_center = uv - cone_center;
	// Компенсация соотношения сторон 1800×800, чтобы конус не сплющивался.
	float aspect = SCREEN_PIXEL_SIZE.y / max(SCREEN_PIXEL_SIZE.x, 0.0001);
	from_center.x *= aspect;

	float dist = length(from_center);
	vec2 dir = normalize(cone_direction);
	float dir_len = length(cone_direction);
	if (dir_len > 0.001) {
		dir = cone_direction / dir_len;
	} else {
		dir = vec2(1.0, 0.0);
	}

	float toward = 0.0;
	if (dist > 0.0001) {
		toward = dot(normalize(from_center), dir);
	}
	float half_angle = cone_angle * 0.5;
	float in_cone = 1.0 - smoothstep(cos(half_angle), cos(half_angle) - 0.08, toward);
	float in_radius = 1.0 - smoothstep(cone_radius * 0.75, cone_radius, dist);
	float light_mask = clamp(in_cone * in_radius, 0.0, 1.0);

	vec4 dark = darkness_color;
	dark.a *= (1.0 - light_mask) * intensity;

	vec4 glow = cone_color;
	glow.a *= light_mask * intensity * 0.55;

	COLOR = vec4(
		mix(dark.rgb, glow.rgb, glow.a),
		clamp(dark.a + glow.a, 0.0, 1.0)
	);
}
