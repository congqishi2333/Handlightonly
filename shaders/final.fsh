#version 330 compatibility

// 唯一需要改的文件：几何 pass 完全交给 Iris 默认渲染，
// 这里只从深度缓冲反算玩家空间坐标，把手光叠加到已经画好的画面上。
uniform sampler2D colortex0;
uniform sampler2D depthtex2;   // 不含手/透明物，避免照亮手持方块本身
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

    int lv = max(heldBlockLightValue, heldBlockLightValue2);
    if (lv > 0) {
        float depth = texture(depthtex2, texcoord).x;
        if (depth < 1.0) {   // 天空不照亮
            // 屏幕 UV + 深度 -> 视空间 -> 以相机为原点的玩家空间
            vec4 viewPos4 = gbufferProjectionInverse
                          * vec4(texcoord * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
            vec3 playerPos = (gbufferModelViewInverse * vec4(viewPos4.xyz / viewPos4.w, 1.0)).xyz;

            float dist = length(playerPos);
            float atten = 1.0 / (1.0 + HL_FALLOFF * dist * dist);
            float handLight = (float(lv) / 15.0) * atten * HL_STRENGTH;

            // 乘在已有颜色上，保留材质本色；直接加常数会把画面洗白
            color.rgb += color.rgb * HL_TINT * handLight;
        }
    }

    outColor0 = color;
}
