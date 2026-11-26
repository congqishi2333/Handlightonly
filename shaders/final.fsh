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
    int lv = max(heldBlockLightValue, heldBlockLightValue2);

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
            vec3 lightAdd = HL_TINT * ((float(lv) / 15.0) * atten * HL_STRENGTH);

            // screen blend：暗处也能抬起来，接近白时不溢出，保留材质色相
            color.rgb = 1.0 - (1.0 - color.rgb) * (1.0 - lightAdd);
        }
    }

    outColor0 = color;
}
