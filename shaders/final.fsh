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

            // 亮度直接跟手持物品的光级挂钩：15 -> 1.0，14 -> 0.933，10 -> 0.667 ...
            // HL_STRENGTH 默认 1.00，就是「和手上物品一样亮」；调低才是额外减弱。
            float amount = (float(lv) / 15.0) * atten * HL_STRENGTH;

            // 最大通道归一化保留像素色相；光色也按最大通道归一化，
            // 所以 RGB 滑块只管色相，不再偷偷改变亮度。
            float m = max(max(color.r, color.g), color.b);
            float ht = max(max(HL_TINT.r, HL_TINT.g), HL_TINT.b);
            vec3 tint = HL_TINT / max(ht, 1e-3);
            vec3 albedo = color.rgb / max(m, 1e-3) * tint;

            // screen 混合：亮处自动少加，不撞上限、不截平细节。
            // clamp 只在 HL_STRENGTH 被拉超过 1.00 时才可能触发。
            color.rgb += (1.0 - color.rgb) * clamp(albedo * amount, 0.0, 1.0);
        }
    }

    outColor0 = color;
}
