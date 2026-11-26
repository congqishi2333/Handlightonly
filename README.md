# Handlightonly

一个极简的 Minecraft Java 版光影包（Iris）：手里拿着发光方块时，在相机位置产生一盏跟着你走的视觉点光源；不拿发光方块时，画面就是原版。

## 做法

**不覆盖任何几何程序**：没有 `gbuffers_*`、没有 `shadow`、没有 `composite`。几何全部由 Iris 默认渲染，只有一个 `final.fsh` 做后处理：

1. 从 `depthtex2`（不含手和透明物）反算当前像素的玩家空间坐标
2. 算它到相机（点光源所在位置）的距离衰减
3. 把光乘到已经画好的画面颜色上

```glsl
vec4 viewPos4 = gbufferProjectionInverse
              * vec4(texcoord * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
vec3 playerPos = (gbufferModelViewInverse * vec4(viewPos4.xyz / viewPos4.w, 1.0)).xyz;
float amount = (float(lv) / 15.0) * atten * HL_STRENGTH;
float lum = dot(color.rgb, vec3(0.299, 0.587, 0.114));
vec3 albedo = color.rgb / max(lum, 0.15);
albedo = mix(HL_TINT * 1.2, albedo, smoothstep(0.0, 0.08, lum));
color.rgb = clamp(color.rgb + albedo * amount, 0.0, 1.0);
```

纯乘法在暗处抬不动亮度；直接加暖白色又会把方块冲成灰。这里用像素自身色相当 albedo 的近似：亮部只补同色光，色相和饱和度不变；纯黑没有色相信息，才用暖色兜底。因为光源就在相机位置，所有可见物体的正面本来就朝向光源，不需要额外的法线/面光计算，墙面、草、箱子也就不会出现亮度不一致。

## 文件结构

```
shaders/
├── shaders.properties        # oldLighting=true，关掉 OptiFine 动态手光
├── final.vsh / final.fsh     # 唯一实际逻辑，在 final.fsh
└── lib/handlight_settings.glsl
```

`shaders.properties` 里 `oldLighting=true` 保留原版方向面光；`oldHandLight=false` 让主副手亮度分别传给 shader（取较大值）。没有使用 `dynamicHandLight`——那是 OptiFine 遗留项，当前 Iris 指令表里没有，写的也会被忽略。

## 安装

1. 下载或克隆本仓库
2. 将仓库内容（含 `shaders/` 文件夹）放到 `.minecraft/shaderpacks/HandLightOnly/`，或使用 Releases 里的 zip
3. 游戏内：视频设置 → 光影 → 选择 `HandLightOnly`
4. 修改 shader 后按 `R` 重载

> **打包注意**：zip 里 `shaders/` 必须在**根目录**（条目形如 `shaders/final.fsh`）。
> 不要把整个 `HandLightOnly/` 文件夹压进去，否则 Iris 找不到根目录的 `shaders/`，会报
> `Pack "..." is not valid! Can't load it.` 并回退到无光影。

适用于 Minecraft 1.21.1 + NeoForge + Iris / Sodium。

## 调参

改 `shaders/lib/handlight_settings.glsl`：

| 宏 | 默认 | 说明 |
|---|---|---|
| `HL_STRENGTH` | `0.60` | 手光强度，建议 0.35~1.0 |
| `HL_FALLOFF` | `0.11` | 距离衰减，越大光圈越小 |
| `HL_TINT` | `vec3(1.00, 0.84, 0.62)` | 光色；红石风格可改为 `vec3(1.0, 0.4, 0.2)` |
| `HL_DEBUG` | `0` | 改成 `1` 后画面灰度显示 `heldBlockLightValue / 15`，用来确认 uniform 在 final 里有值 |

## 已知取舍

- 点光源没有遮挡计算，光会轻微穿薄墙；靠衰减半径把破绽藏住
- 没有表面法线项，掠射角物体也会亮；但光源在相机处，可见正面基本都朝向它，影响很小
- `depthtex2` 不含透明物，水/玻璃表面不会被手光照到
- 只有亮度信息，无法按方块区分颜色，所以萤石/火把/海晶灯共用同一个暖白色
- 纯视觉，不改变世界真实光照等级
