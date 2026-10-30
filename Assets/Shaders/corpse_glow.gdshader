shader_type canvas_item;
// Brilho do cadáver: tinge o sprite na cor do nível (glow 0 -> 1) e depois some (fade 0 -> 1).
// Só é aplicado na hora da morte (os inimigos vivos não levam material, para manter o batching).
// Não usa hint_screen_texture nem luz.

uniform vec4 glow_color : source_color = vec4(0.28, 0.28, 0.71, 1.0);
uniform float glow : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 lit = mix(tex.rgb, glow_color.rgb * 1.4, glow); // 1.4 = brilho extra (palpite)
	COLOR = vec4(lit, tex.a * (1.0 - fade));
}
