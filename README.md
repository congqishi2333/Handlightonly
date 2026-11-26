# Handlightonly

仅为手持的光源方块提供移动光源。

一个极简的 Minecraft Java 版光影包（Iris / OptiFine）：只做一件事——手里拿着发光方块时，在相机位置产生一盏跟着你走的视觉点光源。不拿发光方块时，画面基本等于原版。

## 效果

- 手持火把、萤石、灯笼、海晶灯等发光方块时，周围物体被暖白色的光斑照亮
- 移动时，光斑随玩家连续扫过墙面和地面
- 不渲染阴影、不做 PBR、没有 Bloom / SSAO 等后处理

## 安装

1. 下载或克隆本仓库
2. 将仓库内容（含 `shaders/` 文件夹）放到 `.minecraft/shaderpacks/HandLightOnly/`，或直接下载 Releases 里的 zip
3. 游戏内：选项 → 视频设置 → 光影 → 选择 `HandLightOnly`
4. 修改 shader 文件后按 `R` 重载

适用于 Minecraft 1.21.1 + NeoForge + Iris / Sodium。

## 文件结构

```
shaders/
├── shaders.properties
├── gbuffers_terrain.vsh / .fsh        # 地形显式程序
├── gbuffers_textured_lit.vsh / .fsh   # 其余受光几何的兜底程序
└── final.vsh / .fsh                   # 一次全屏拷贝
```

### 为什么这么轻

- 两个 gbuffers 程序：`gbuffers_terrain` 显式覆盖地形，`gbuffers_textured_lit` 覆盖 entities / block / hand / water / 粒子
- Sodium/Iris 会把 terrain 拆成 `gbuffers_terrain_solid` / `gbuffers_terrain_cutout`，二者都回退到 `gbuffers_terrain`；只写兜底程序地形可能吃不到手光
- `shadow.enabled=false`，完全不跑 shadow pass
- 没有 composite / deferred，只有一次 `final` 拷贝
- 每像素只在手持光源时多算一次 `length` + `dot` + 除法

### 原理

光源坐标直接取相机位置。`gbufferModelViewInverse` 把顶点变换到以相机为原点的玩家空间，因此点光源就在原点：

```glsl
int lv = max(heldBlockLightValue, heldBlockLightValue2);
float level = float(lv) / 15.0;
float dist = length(playerPos);
float atten = 1.0 / (1.0 + HL_FALLOFF * dist * dist);
color += HL_TINT * (level * atten * diff * HL_STRENGTH);
```

`heldBlockLightValue` 是 Iris/OptiFine 提供的 uniform，表示手持方块的亮度等级（0~15）。

基础颜色只用 `texel.rgb * glcolor.rgb`：`oldLighting=true` 时 `gl_Color` 已经包含原版光照，不再额外乘 `lightmap`，避免重复压暗。

## 调参

在 `shaders/gbuffers_textured_lit.fsh` 顶部：

| 宏 | 默认 | 说明 |
|---|---|---|
| `HL_STRENGTH` | `0.60` | 光强，建议 0.35~1.0 |
| `HL_FALLOFF` | `0.11` | 衰减，越大照射范围越小 |
| `HL_TINT` | `vec3(1.00, 0.84, 0.62)` | 光色；红石风格可改为 `vec3(1.0, 0.4, 0.2)` |

## 已知取舍

- 点光源没有遮挡计算，光会轻微穿薄墙；靠衰减半径把破绽藏住
- 只有亮度信息，无法按方块区分颜色，所以萤石/火把/海晶灯共用同一个暖白色
- 纯视觉，不改变世界真实光照等级（不是 OptiFine Dynamic Lights 那种 CPU 光照更新）
