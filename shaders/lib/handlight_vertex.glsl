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
