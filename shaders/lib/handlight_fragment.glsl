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

// 把相机相对的玩家空间坐标投到 shadow map 坐标，沿用 Complementary 的畸变修正
float GetShadow(vec3 pos) {
    vec3 shadowView = mat3(shadowModelView) * pos + shadowModelView[3].xyz;
    vec3 shadowPos = vec3(shadowProjection[0].x, shadowProjection[1].y, shadowProjection[2].z)
                   * shadowView + shadowProjection[3].xyz;

    float bias = 1.0 - 25.6 / shadowDistance;
    float dist = length(shadowPos.xy);
    shadowPos.xy /= dist * bias + (1.0 - bias);
    shadowPos.z *= 0.2;
    shadowPos = shadowPos * 0.5 + 0.5;

    // 超出阴影贴图覆盖范围时视为无阴影
    if (shadowPos.x < 0.0 || shadowPos.x > 1.0 ||
        shadowPos.y < 0.0 || shadowPos.y > 1.0 ||
        shadowPos.z < 0.0 || shadowPos.z > 1.0) return 1.0;

    return shadow2D(shadowtex1, shadowPos).x;
}

void main() {
    vec4 texel = texture(gtexture, texcoord);
    if (texel.a < 0.1) discard;

    // gl_Color 只含面朝向明暗 + AO；天光/方块光在 lightmap 里，必须乘回来
    vec3 lightColor = texture(lightmap, lmcoord).rgb;

    // 阴影只压暗天光部分，方块光不受影响；手持物本身不投射阴影
    float skyLevel = clamp((lmcoord.y - 0.03125) * 1.06667, 0.0, 1.0);
    #ifdef GBUFFERS_HAND
        float skyShadow = 1.0;
    #else
        float shadow = GetShadow(playerPos);
        float skyShadow = mix(1.0, 0.35 + 0.65 * shadow, skyLevel * 0.85);
    #endif
    lightColor *= skyShadow;

    // 手动还原原版方向面光（oldLighting=false 时 gl_Color 只剩 AO + 染色）：
    // 顶面 1.0 / 侧面 0.8 / 底面 0.5。只给地形用，实体不需要这套。
    float faceLight = 1.0;
    #ifdef GBUFFERS_TERRAIN
        float ny = normalize(normalWorld).y;
        faceLight = ny > 0.5 ? 1.0 : (ny < -0.5 ? 0.5 : 0.8);
    #endif

    vec3 color = texel.rgb * glcolor.rgb * lightColor * faceLight;

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
