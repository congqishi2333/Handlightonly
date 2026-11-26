#version 330 compatibility

// Iris 不会自动注入这个宏，必须在程序文件里显式定义
#define GBUFFERS_HAND

/* RENDERTARGETS: 0 */
#include "/lib/handlight_settings.glsl"
#include "/lib/handlight_fragment.glsl"

