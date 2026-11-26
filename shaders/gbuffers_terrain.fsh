#version 330 compatibility

// Iris 不会自动注入这个宏，必须显式定义（用于地形墙面额外压暗）
#define GBUFFERS_TERRAIN

/* RENDERTARGETS: 0 */
#include "/lib/handlight_settings.glsl"
#include "/lib/handlight_fragment.glsl"
