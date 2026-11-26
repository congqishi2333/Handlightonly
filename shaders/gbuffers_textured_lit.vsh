#version 330 compatibility

// 所有受光几何的兜底程序：entities / block / hand / water / 粒子等会回退到这里
// terrain 有显式程序 gbuffers_terrain，见同名文件

uniform mat4 gbufferModelViewInverse;

out vec2 texcoord;
out vec4 glcolor;

// 相机相对坐标：相机在原点，所以手持光源就在原点
out vec3 playerPos;
// 世界/玩家空间法线，和 playerPos 同一坐标系
out vec3 normalWorld;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor  = gl_Color;   // oldLighting=true 时已含原版光照

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;

    playerPos   = (gbufferModelViewInverse * viewPos).xyz;
    normalWorld = mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal);

    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
}
