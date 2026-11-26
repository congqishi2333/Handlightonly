#version 330 compatibility

// 这一个 program 是所有受光几何的兜底程序：
// terrain / entities / block / hand / water / 粒子 都会回退到这里

uniform mat4 gbufferModelViewInverse;

out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;

// 相机相对坐标：相机在原点，所以手持光源就在原点
out vec3 playerPos;
// 世界/玩家空间法线，和 playerPos 同一坐标系
out vec3 normalWorld;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor  = gl_Color;

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;

    // 视空间 -> 玩家空间（相机为原点，仅平移，不减精度）
    playerPos    = (gbufferModelViewInverse * viewPos).xyz;
    normalWorld  = mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal);

    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
}
