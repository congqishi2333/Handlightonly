#version 330 compatibility

// 不用 ftransform()：显式写矩阵变换。Iris 当前文档仍推荐 compatibility profile。
out vec2 texcoord;

void main() {
    gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
