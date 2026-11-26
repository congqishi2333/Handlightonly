#version 330 compatibility

// ============ 可调参数（改完按 R 重载） ============
#define HL_STRENGTH  0.60                    // 光强，0.35~1.0 之间调
#define HL_FALLOFF   0.11                    // 衰减，越大照射范围越小
#define HL_TINT      vec3(1.00, 0.84, 0.62)  // 光色，暖白；想要红石火把感改成 vec3(1.0,0.4,0.2)
// =================================================

uniform sampler2D gtexture;
uniform sampler2D lightmap;

// 手持方块的亮度，0~15；副手同理
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 playerPos;
in vec3 normalWorld;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor0;

void main() {
    vec4 texel = texture(gtexture, texcoord);
    if (texel.a < 0.1) discard;              // 树叶/玻璃/水的 alpha 测试

    // 完全保留原版光照（oldLighting=true 时 glcolor 里还有方向面光）
    vec4 light = texture(lightmap, lmcoord);
    vec3 color = texel.rgb * glcolor.rgb * light.rgb;

    // ---- 手持发光方块 => 相机处的一盏点光源 ----
    int lv = max(heldBlockLightValue, heldBlockLightValue2);
    if (lv > 0) {
        float level = float(lv) / 15.0;

        float dist = length(playerPos);
        vec3  L    = -playerPos / max(dist, 1.0e-4);   // 从像素指向相机（光源）

        float atten = 1.0 / (1.0 + HL_FALLOFF * dist * dist);

        vec3  N    = normalize(normalWorld);
        float diff = max(dot(N, L), 0.0);              // 兰伯特
        float wrap = max(dot(N, L) * 0.5 + 0.5, 0.0);  // 背光面留一点散射

        color += HL_TINT * (level * atten * mix(diff, wrap, 0.35) * HL_STRENGTH);
    }

    outColor0 = vec4(color, texel.a * glcolor.a);
}
