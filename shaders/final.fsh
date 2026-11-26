#version 330 compatibility

// 唯一的实际程序：几何全部交给 Iris 默认渲染，这里只叠加手持光。
uniform sampler2D colortex0;
uniform sampler2D depthtex2;   // Iris 里对应 RenderTargets.getDepthTextureNoHand()
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor0;

#include "/lib/handlight_settings.glsl"

void main() {
    vec4 color = texture(colortex0, texcoord);

    // Iris 给所有程序（含 final）注册 heldBlockLightValue，PER_FRAME 更新。
    // 部分模组方块可能返回 > 15 的亮度，夹到原版上限，避免近处爆亮。
    int lv = min(max(heldBlockLightValue, heldBlockLightValue2), 15);

    #if HL_DEBUG == 1
        // 调试：屏幕灰度 = 手持亮度 / 15，用来确认 uniform 在 final 里确实有值
        outColor0 = vec4(vec3(float(lv) / 15.0), 1.0);
        return;
    #endif

    if (lv > 0) {
        float depth = texture(depthtex2, texcoord).x;
        if (depth < 1.0) {   // 天空不照亮
            // 屏幕 UV + 深度 -> 视空间 -> 以相机为原点的玩家空间
            vec4 viewPos4 = gbufferProjectionInverse
                          * vec4(texcoord * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
            vec3 playerPos = (gbufferModelViewInverse * vec4(viewPos4.xyz / viewPos4.w, 1.0)).xyz;

            float dist = length(playerPos);
            float atten = 1.0 / (1.0 + HL_FALLOFF * dist * dist);
            // HL_TINT 直接就是单通道光量（默认三通道各 0.20），HL_STRENGTH 只是倍率。
            vec3 lightAdd = HL_TINT * ((float(lv) / 15.0) * atten * HL_STRENGTH);

            // 用像素自身色相近似 albedo，再乘上光色：亮部保色相，暗部中性兜底。
            // albedo 限幅到 1.0，避免高饱和像素被反向放大成爆亮。
            float lum = dot(color.rgb, vec3(0.299, 0.587, 0.114));
            vec3 albedo = clamp(color.rgb / max(lum, 0.15), 0.0, 1.0);
            albedo = mix(vec3(1.0), albedo, smoothstep(0.0, 0.08, lum));
            color.rgb = clamp(color.rgb + albedo * lightAdd, 0.0, 1.0);
        }
    }

    outColor0 = color;
}
