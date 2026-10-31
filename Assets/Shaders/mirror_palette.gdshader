shader_type canvas_item;
// Paleta alternativa do chefe-espelho (o sprite do jogador com outras cores): gira o matiz, ajusta saturação/brilho e tinge.
// Tem os mesmos uniforms do efeito de portal (glow_color, glow, fade) para a chegada e a morte usarem ESTE material
// e não trocarem de paleta no meio do efeito. `warn` pinta o corpo de vermelho por um instante (aviso antes da rajada).
// Não usa hint_screen_texture nem luz.

uniform vec4 glow_color : source_color = vec4(1.0, 0.46, 0.09, 1.0);
uniform float glow : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 0.0;
uniform float warn : hint_range(0.0, 1.0) = 0.0;
uniform float hue_shift = 0.5; // palpite: meia volta no círculo de cores
uniform float saturation = 1.35;
uniform float brightness = 0.8;
uniform vec4 tint : source_color = vec4(0.75, 0.2, 0.45, 1.0);
uniform float tint_amount = 0.3; // sem isso, pixels cinza (sem matiz) não mudariam de cor

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 hsv = rgb2hsv(tex.rgb);
	hsv.x = fract(hsv.x + hue_shift);
	hsv.y = clamp(hsv.y * saturation, 0.0, 1.0);
	hsv.z = clamp(hsv.z * brightness, 0.0, 1.0);
	vec3 pal = hsv2rgb(hsv);
	float lum = dot(pal, vec3(0.299, 0.587, 0.114));
	pal = mix(pal, tint.rgb * (0.4 + lum * 1.2), tint_amount);
	pal = mix(pal, vec3(1.0, 0.2, 0.15), warn * 0.55);
	vec3 lit = mix(pal, glow_color.rgb * 1.4, glow);
	COLOR = vec4(lit, tex.a * (1.0 - fade));
}
