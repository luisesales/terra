shader_type canvas_item;
render_mode blend_add;
// Tinge o traço preto do círculo de invocação: alpha = tex.a * (1 - luminância), reforçado.
// Funciona com fundo transparente (SVG) e com fundo branco opaco (PNG do pacote).
// A cor vem de `tint` (cor do nível); `alpha` é animado por tween para aparecer/sumir.
// blend_add + traço reforçado: o círculo "brilha" e continua visível depois do escurecimento da tela.

uniform vec4 tint : source_color = vec4(0.28, 0.28, 0.71, 1.0);
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
uniform float stroke_boost = 2.5; // palpite: engrossa o traço fino do SVG reduzido
uniform float glow = 1.4; // palpite: brilho da cor

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float a = clamp(tex.a * (1.0 - lum) * stroke_boost, 0.0, 1.0);
	COLOR = vec4(tint.rgb * glow, a * alpha);
}
