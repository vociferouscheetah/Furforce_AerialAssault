shader_type spatial;
render_mode depth_draw_opaque;

uniform vec4  color_shallow : source_color = vec4(0.10, 0.55, 0.75, 1.0);
uniform vec4  color_deep    : source_color = vec4(0.02, 0.15, 0.38, 1.0);
uniform float wave_height   : hint_range(0.0, 30.0)  = 6.0;
uniform float wave_speed    : hint_range(0.0, 5.0)   = 0.7;
uniform float wave_scale    : hint_range(0.001, 0.2) = 0.035;
uniform float metallic      : hint_range(0.0, 1.0)   = 0.15;
uniform float roughness     : hint_range(0.0, 1.0)   = 0.07;
uniform float foam_threshold: hint_range(0.0, 1.0)   = 0.65;

// ---------------------------------------------------------------------------
// Noise helpers
// ---------------------------------------------------------------------------
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float smooth_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);   // smooth step
	return mix(
		mix(hash(i),              hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

// Fractional Brownian Motion — layered noise for choppy ocean surface
float fbm(vec2 p) {
	float v     = 0.0;
	float amp   = 0.5;
	mat2  rot   = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 5; i++) {
		v  += amp * smooth_noise(p);
		p   = rot * p * 2.1 + vec2(1.7, 9.2);
		amp *= 0.5;
	}
	return v;
}

// ---------------------------------------------------------------------------
// Wave height function — called twice per vertex for normal computation
// ---------------------------------------------------------------------------
float get_wave_height(vec2 world_xz, float t) {
	vec2 uv = world_xz * wave_scale;

	// Four directional sine waves for the large swell shape
	float w1 = sin(uv.x * 2.1  + t          ) * 0.45;
	float w2 = sin(uv.y * 1.8  + t * 0.85 + 1.3) * 0.38;
	float w3 = sin((uv.x + uv.y) * 1.4 + t * 1.1 + 0.5) * 0.28;
	float w4 = sin((uv.x - uv.y) * 0.9 + t * 0.6 + 2.1) * 0.20;

	// FBM noise layer for choppiness and irregularity
	float choppy = fbm(uv + vec2(t * 0.22, t * 0.16)) * 2.0 - 1.0;

	return (w1 + w2 + w3 + w4 + choppy * 0.45) * wave_height;
}

// ---------------------------------------------------------------------------
// Varyings
// ---------------------------------------------------------------------------
varying float v_wave_t;    // 0–1 normalized wave height (for colour blending)

// ---------------------------------------------------------------------------
// Vertex — displace Y and recompute normal via finite differences
// ---------------------------------------------------------------------------
void vertex() {
	vec3  world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t         = TIME * wave_speed;

	float h   = get_wave_height(world_pos.xz, t);
	VERTEX.y += h;

	// Normalise wave height to 0–1 for colour lerp in fragment
	v_wave_t = clamp(h / wave_height * 0.5 + 0.5, 0.0, 1.0);

	// Finite-difference normals — sample two neighbours to build tangents
	float eps = 0.9;
	float hx  = get_wave_height(world_pos.xz + vec2(eps, 0.0), t);
	float hz  = get_wave_height(world_pos.xz + vec2(0.0, eps), t);

	vec3 tangent_x = normalize(vec3(eps, hx - h,  0.0));
	vec3 tangent_z = normalize(vec3(0.0,  hz - h, eps));
	NORMAL = normalize(cross(tangent_z, tangent_x));
}

// ---------------------------------------------------------------------------
// Fragment — PBR water material with depth colour and foam
// ---------------------------------------------------------------------------
void fragment() {
	// Blend deep → shallow colour based on wave height
	vec3 water_col = mix(color_deep.rgb, color_shallow.rgb, v_wave_t);

	// Foam on wave crests
	float foam  = smoothstep(foam_threshold, 1.0, v_wave_t);
	water_col   = mix(water_col, vec3(1.0), foam * 0.45);

	ALBEDO    = water_col;
	METALLIC  = metallic;
	ROUGHNESS = roughness;
	SPECULAR  = 0.9;   // strong specular for water glint
}
