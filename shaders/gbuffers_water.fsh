#version 330 compatibility

// Iris 不会自动注入这个宏：用来跳过全局 alpha discard，保留水/玻璃半透明边缘
#define GBUFFERS_WATER

/* RENDERTARGETS: 0 */
#include "/lib/handlight_settings.glsl"
#include "/lib/handlight_fragment.glsl"

