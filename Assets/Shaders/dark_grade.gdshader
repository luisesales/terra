shader_type canvas_item;
// Escurecimento em um passe só: dessaturação, valor, contraste, tom frio leve e vinheta.
// Lê a tela (hint_screen_texture): use apenas num ColorRect de tela cheia, num CanvasLayer ABAIXO do HUD.
// Todos os valores são palpite e ficam como uniforms para ajustar no Inspector.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float desaturation : hint_range(0.0, 1.0) = 0.55; // 0 = cor original, 1 = preto e branco
uniform float value_scale : hint_range(0.0, 2.0) = 0.9;
uniform float contrast : hint_range(0.5, 2.0) = 1.15; // em torno de 0,5
uniform vec3 cool_tint : source_color = vec3(0.92, 0.98, 1.08); // multiplicador azulado
uniform float tint_strength : hint_range(0.0, 1.0) = 0.5;
uniform float inner_radius : hint_range(0.0, 2.0) = 0.6; // vinheta: 0 = centro, 1 = meio da borda, ~1,41 = canto
uniform float outer_radius : hint_range(0.0, 2.0) = 1.4;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec3 c = texture(screen_texture, SCREEN_UV).rgb;
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(luma), desaturation);
	c *= value_scale;
	c = (c - 0.5) * contrast + 0.5;
	c *= mix(vec3(1.0), cool_tint, tint_strength);
	float d = length((UV - 0.5) * 2.0);
	c *= 1.0 - smoothstep(inner_radius, outer_radius, d) * vignette_strength;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
