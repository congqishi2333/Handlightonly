#version 330 compatibility

// 普通的拷贝 pass，把 gbuffers 画好的 colortex0 原样送到屏幕
uniform sampler2D colortex0;
in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor0;

void main() {
    outColor0 = texture(colortex0, texcoord);
}
