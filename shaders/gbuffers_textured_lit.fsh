#version 330 compatibility

// ============ 可调参数（改完按 R 重载） ============
#define HL_STRENGTH  0.60                    // 光强，0.35~1.0 之间调
#define HL_FALLOFF   0.11                    // 衰减，越大照射范围越小
#define HL_TINT      vec3(1.00, 0.84, 0.62)  // 光色，暖白
// =================================================

uniform sampler2D gtexture;

// 手持方块的亮度，0~15；副手同理
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

in vec2 texcoord;
in vec4 glcolor;
in vec3 playerPos;
in vec3 normalWorld;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor0;

void main() {
    vec4 texel = texture(gtexture, texcoord);
    if (texel.a < 0.1) discard;              // 树叶/玻璃/水的 alpha 测试

    // oldLighting=true 时 gl_Color 已包含原版光照，不再重复乘 lightmap
    vec3 color = texel.rgb * glcolor.rgb;

    // ---- 手持发光方块 => 相机处的一盏点光源 ----
    int lv = max(heldBlockLightValue, heldBlockLightValue2);
    if (lv > 0) {
        float level = float(lv) / 15.0;

        float dist = length(playerPos);
        vec3  L    = -playerPos / max(dist, 1.0e-4);

        float atten = 1.0 / (1.0 + HL_FALLOFF * dist * dist);

        vec3  N    = normalize(normalWorld);
        float diff = max(dot(N, L), 0.0);
        float wrap = max(dot(N, L) * 0.5 + 0.5, 0.0);

        color += HL_TINT * (level * atten * mix(diff, wrap, 0.35) * HL_STRENGTH);
    }

    outColor0 = vec4(color, texel.a * glcolor.a);
}
