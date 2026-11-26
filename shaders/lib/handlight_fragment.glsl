uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 playerPos;
in vec3 normalWorld;

layout(location = 0) out vec4 outColor0;

void main() {
    vec4 texel = texture(gtexture, texcoord);
    if (texel.a < 0.1) discard;

    // gl_Color 只含面朝向明暗 + AO；天光/方块光在 lightmap 里，必须乘回来
    vec4 light = texture(lightmap, lmcoord);
    vec3 color = texel.rgb * glcolor.rgb * light.rgb;

    int lv = max(heldBlockLightValue, heldBlockLightValue2);
    if (lv > 0) {
        float level = float(lv) / 15.0;
        float dist  = length(playerPos);
        vec3  L     = -playerPos / max(dist, 1.0e-4);

        float atten = 1.0 / (1.0 + HL_FALLOFF * dist * dist);

        vec3  N    = normalize(normalWorld);
        float diff = max(dot(N, L), 0.0);
        float wrap = max(dot(N, L) * 0.5 + 0.5, 0.0);

        color += HL_TINT * (level * atten * mix(diff, wrap, 0.35) * HL_STRENGTH);
    }

    outColor0 = vec4(color, texel.a * glcolor.a);
}
