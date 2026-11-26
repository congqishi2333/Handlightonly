uniform mat4 gbufferModelViewInverse;

out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 playerPos;
out vec3 normalWorld;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord  = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor  = gl_Color;   // oldLighting=true：面朝向明暗 + AO，不含 lightmap

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;

    playerPos   = (gbufferModelViewInverse * viewPos).xyz;
    normalWorld = mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal);

    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
}
