# Handlightonly

仅为手持的光源方块提供移动光源。

一个极简的 Minecraft Java 版光影包（Iris / OptiFine）：只做一件事——手里拿着发光方块时，在相机位置产生一盏跟着你走的视觉点光源。不拿发光方块时，画面基本等于原版。

## 效果

- 手持火把、萤石、灯笼、海晶灯等发光方块时，周围物体被暖白色的光斑照亮
- 移动时，光斑随玩家连续扫过墙面和地面
- 只做一次太阳/月亮阴影采样，不做 PBR、没有 Bloom / SSAO 等后处理

## 安装

1. 下载或克隆本仓库
2. 将仓库内容（含 `shaders/` 文件夹）放到 `.minecraft/shaderpacks/HandLightOnly/`，或直接下载 Releases 里的 zip
3. 游戏内：选项 → 视频设置 → 光影 → 选择 `HandLightOnly`
4. 修改 shader 文件后按 `R` 重载

> **打包注意**：zip 里 `shaders/` 必须在**根目录**（条目形如 `shaders/shaders.properties`）。
> 不要把整个 `HandLightOnly/` 文件夹压进去，否则 Iris 找不到根目录的 `shaders/`，会报
> `Pack "..." is not valid! Can't load it.` 并回退到无光影。

适用于 Minecraft 1.21.1 + NeoForge + Iris / Sodium。

## 文件结构

```
shaders/
├── shaders.properties
├── lib/
│   ├── handlight_settings.glsl        # 唯一需要调参的地方
│   ├── handlight_vertex.glsl
│   └── handlight_fragment.glsl
├── gbuffers_terrain.vsh / .fsh        # 地形
├── gbuffers_entities.vsh / .fsh       # 实体
├── gbuffers_block.vsh / .fsh          # 方块实体 / 告示牌
├── gbuffers_hand.vsh / .fsh           # 手 / 手持物
├── gbuffers_water.vsh / .fsh          # 水 / 半透明方块
├── gbuffers_textured_lit.vsh / .fsh   # 粒子等兜底
├── final.vsh / .fsh                   # 一次全屏拷贝
└── lang/zh_cn.lang, en_us.lang        # 游戏内滑块的中英文标签
```

### 为什么这么轻

- 六个 gbuffers 程序全部显式声明，走 Iris 的原生路由，不依赖 OptiFine 时代的 `gbuffers_textured_lit` 兜底
- 每个程序文件只有几行，实际逻辑都在 `lib/` 的三个 include 里；参数可以直接在游戏里拖滑块，不用改文件
- Sodium/Iris 的 `gbuffers_terrain_solid` / `gbuffers_terrain_cutout` 回退到 `gbuffers_terrain`；`gbuffers_entities_translucent` / `gbuffers_block_translucent` 回退到各自的程序，所以主要几何都被覆盖
- `shadow.enabled=true`，但不写自己的 `shadow.vsh/.fsh`，用 Iris 默认 shadow shader；gbuffers 里只采样一次 `shadowtex1`，且只压暗天光（方块光不受阴影影响）
- 没有 composite / deferred，只有一次 `final` 拷贝
- 每像素只在手持光源时多算一次 `length` + `dot` + 除法

### 原理

光源坐标直接取相机位置。`gbufferModelViewInverse` 把顶点变换到以相机为原点的玩家空间，因此点光源就在原点：

```glsl
int lv = max(heldBlockLightValue, heldBlockLightValue2);
float level = float(lv) / 15.0;
float dist = length(playerPos);
float atten = 1.0 / (1.0 + HL_FALLOFF * dist * dist);
color += texel.rgb * HL_TINT * (level * atten * diff * HL_STRENGTH);
```

手光项必须乘 `texel.rgb`：直接加一个固定颜色会让所有方块都混进同一层暖白，看起来灰蒙蒙、颜色发灰。乘回 albedo 后，红石还是红的、草方块还是绿的，只是变亮。

`heldBlockLightValue` 是 Iris/OptiFine 提供的 uniform，表示手持方块的亮度等级（0~15）。

基础颜色必须同时乘 `gl_Color` 和 `lightmap`：`gl_Color` 提供 AO 和方块染色，天光和方块光在 `lightmap` 纹理里。两者不是重复，只乘其中一个都会让画面明显偏离原版。

方向面光由滑块决定（`oldLighting=false`，所以 `gl_Color` 不再带朝向系数）：顶面 `1.0` / 南北面 `0.8` / 东西面 `0.6` / 底面 `0.5`，草、花等斜法线植物用单独的 `1.0`。原版系数只是默认值，全部可以在游戏里拖滑块覆盖。

查表顺序保持原版：原版 chunk shader 是 `vertexColor = Color * minecraft_sample_lightmap(...)`，即先查 lightmap、再乘顶点色。所以 shader 里用 `texture(lightmap, lmcoord)`，面光系数也是查表之后乘，不做 `lmcoord` 缩放。

`GBUFFERS_TERRAIN` / `GBUFFERS_HAND` 这类宏 Iris 不会自动注入，必须在对应 `.fsh` 里显式 `#define`。本包两个都定义了：前者用于按朝向应用面光滑块，后者用于跳过手持物自身的阴影采样。

## 调参

游戏内：视频设置 → 光影 → 光影包设置（Shader Pack Settings），在「面向亮度」子屏幕里拖动滑块；改完按 `R` 重载。宏定义在 `shaders/lib/handlight_settings.glsl`，滑块取值范围也写在那里的注释中：

| 选项 | 默认 | 说明 |
|---|---|---|
| `HL_FACE_TOP` | `1.0` | 顶面亮度（原版 1.0） |
| `HL_FACE_NS` | `0.8` | 南北墙面亮度（原版 0.8） |
| `HL_FACE_EW` | `0.6` | 东西墙面亮度（原版 0.6） |
| `HL_FACE_BOTTOM` | `0.5` | 底面亮度（原版 0.5） |
| `HL_FACE_PLANT` | `1.0` | 草/花等斜法线植物亮度，不参与墙面判定 |
| `HL_STRENGTH` | `0.60` | 手光强度，建议 0.35~1.0 |
| `HL_FALLOFF` | `0.11` | 衰减，越大照射范围越小 |
| `HL_TINT` | `vec3(1.00, 0.84, 0.62)` | 光色（不是滑块，需改文件）；红石风格可改为 `vec3(1.0, 0.4, 0.2)` |

## 已知取舍

- 点光源没有遮挡计算，光会轻微穿薄墙；靠衰减半径把破绽藏住
- 只有亮度信息，无法按方块区分颜色，所以萤石/火把/海晶灯共用同一个暖白色
- 纯视觉，不改变世界真实光照等级（不是 OptiFine Dynamic Lights 那种 CPU 光照更新）
