#version 330 compatibility

// 地形显式程序。Sodium/Iris 下 terrain 会拆成 solid/cutout 并回退到 gbuffers_terrain，
// 不能只靠 gbuffers_textured_lit 兜底，否则地形吃不到手光。

uniform mat4 gbufferModelViewInverse;

out vec2 texcoord;
out vec4 glcolor;
out vec3 playerPos;
out vec3 normalWorld;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor  = gl_Color;

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;

    playerPos   = (gbufferModelViewInverse * viewPos).xyz;
    normalWorld = mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal);

    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
}
