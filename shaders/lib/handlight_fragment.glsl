uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

// 阴影 pass 相关（Iris 默认 shadow shader 渲染 shadowtex0/1）
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform float shadowDistance;
uniform sampler2DShadow shadowtex1;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 playerPos;
in vec3 normalWorld;

layout(location = 0) out vec4 outColor0;

// 把相机相对的玩家空间坐标投到 shadow map 坐标。
// 本包没有 shadow.vsh/.fsh，Iris 用内置 shadow pass 写 shadowtex1：
// 它不做 lens distortion，采样端也绝不能做，否则读写不对称会错位/条纹。
float GetShadow(vec3 pos) {
    vec3 shadowView = (shadowModelView * vec4(pos, 1.0)).xyz;
    vec4 shadowClip = shadowProjection * vec4(shadowView, 1.0);
    vec3 shadowPos = shadowClip.xyz / shadowClip.w * 0.5 + 0.5;

    // 轻微深度偏移，避免自阴影 acne
    shadowPos.z -= 0.001;

    // 超出阴影贴图覆盖范围时视为无阴影
    if (shadowPos.x < 0.0 || shadowPos.x > 1.0 ||
        shadowPos.y < 0.0 || shadowPos.y > 1.0 ||
        shadowPos.z < 0.0 || shadowPos.z > 1.0) return 1.0;

    return shadow2D(shadowtex1, shadowPos).x;
}

void main() {
    vec4 texel = texture(gtexture, texcoord);
    // 水/玻璃的半透明边缘不能被全局 alpha 测试裁掉
    #ifndef GBUFFERS_WATER
        if (texel.a < 0.1) discard;
    #endif

    // lightmap 用原始 lmcoord 查表，和原版一样「查表后再乘顶点色」
    vec3 lightColor = texture(lightmap, lmcoord).rgb;

    // 各朝向的亮度完全由 Iris 滑块控制（oldLighting=false 时 gl_Color 只剩 AO + 染色）
    #ifdef GBUFFERS_TERRAIN
        vec3 n = normalize(normalWorld);
        float faceLight;
        if      (n.y >  0.5)                          faceLight = HL_FACE_TOP;
        else if (n.y < -0.5)                          faceLight = HL_FACE_BOTTOM;
        else if (abs(abs(n.x) - abs(n.z)) < 0.3)       faceLight = HL_FACE_PLANT;  // 草/花等斜法线
        else if (abs(n.x) > 0.5)                       faceLight = HL_FACE_EW;
        else                                           faceLight = HL_FACE_NS;
        lightColor *= faceLight;
    #endif

    // 阴影只压暗天光部分，方块光不受影响；手持物本身不投射阴影
    float skyLevel = clamp((lmcoord.y - 0.03125) * 1.06667, 0.0, 1.0);
    #ifdef GBUFFERS_HAND
        float skyShadow = 1.0;
    #else
        float shadow = GetShadow(playerPos);
        float skyShadow = mix(1.0, 0.35 + 0.65 * shadow, skyLevel * 0.85);
    #endif
    lightColor *= skyShadow;

    vec3 color = texel.rgb * glcolor.rgb * lightColor;

    int lv = max(heldBlockLightValue, heldBlockLightValue2);
    if (lv > 0) {
        float level = float(lv) / 15.0;
        float dist  = length(playerPos);
        vec3  L     = -playerPos / max(dist, 1.0e-4);

        float atten = 1.0 / (1.0 + HL_FALLOFF * dist * dist);

        vec3  N    = normalize(normalWorld);
        float diff = max(dot(N, L), 0.0);
        float wrap = max(dot(N, L) * 0.5 + 0.5, 0.0);

        // 手光必须乘表面 albedo，否则所有方块都被叠上同一层暖白，看起来灰蒙蒙/褪色
        float handLight = level * atten * mix(diff, wrap, 0.35) * HL_STRENGTH;
        color += texel.rgb * HL_TINT * handLight;
    }

    outColor0 = vec4(color, texel.a * glcolor.a);
}
