shader_type canvas_item;
// Logo do menu: o PNG (Assets/Models/Logo) tem letras pretas sobre fundo transparente e o menu é preto.
// Aqui só o alfa do PNG é usado; a cor vem de `tint` (branco por padrão). Sem este material o logo aparece preto.

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	COLOR = vec4(tint.rgb, COLOR.a * tint.a);
}
