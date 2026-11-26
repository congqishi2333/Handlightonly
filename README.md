# Handlightonly

一个极简的 Minecraft Java 版光影包（Iris）：手里拿着发光方块时，在相机位置产生一盏跟着你走的视觉点光源；不拿发光方块时，画面就是原版。

## 做法

**不覆盖任何几何程序**：没有 `gbuffers_*`、没有 `shadow`、没有 `composite`。几何全部由 Iris 默认渲染，只有一个 `final.fsh` 做后处理：

1. 从 `depthtex2`（不含手和透明物）反算当前像素的玩家空间坐标
2. 算它到相机（点光源所在位置）的距离衰减
3. 按像素自身色相把光加到已经画好的画面上

```glsl
vec4 viewPos4 = gbufferProjectionInverse
              * vec4(texcoord * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
vec3 playerPos = (gbufferModelViewInverse * vec4(viewPos4.xyz / viewPos4.w, 1.0)).xyz;
float amount = (float(lv) / 15.0) * atten * HL_STRENGTH;
float m = max(max(color.r, color.g), color.b);
float ht = max(max(HL_TINT.r, HL_TINT.g), HL_TINT.b);
vec3 tint = HL_TINT / max(ht, 1e-3);
vec3 albedo = color.rgb / max(m, 1e-3) * tint;
color.rgb += (1.0 - color.rgb) * clamp(albedo * amount, 0.0, 1.0);
```

亮度核心就是这一行：`float(lv) / 15.0`。`lv` 是 Iris 传进来的手持物品光级（主/副手取较大值，并夹到原版上限 15），所以：

| 手持光级 | 光量系数 |
|---:|---:|
| 15（萤石/海晶灯） | 1.00 |
| 14（火把） | 0.93 |
| 10 | 0.67 |
| 5 | 0.33 |

`atten` 是根据距离做的衰减，模拟手光源在相机位置。`HL_STRENGTH` 默认 `1.00`，也就是**不再额外缩放，直接等于手上物品的光级**；调低才人为减弱，调高则加强。

色相用**最大通道**归一化：分量天然落在 `[0,1]`，不会再被放大到撞 `clamp(...,1.0)` 截平；暗的彩色方块归一化后仍是自己的色相。`HL_TINT` 也按最大通道归一化，所以 RGB 滑块**只控制颜色，不影响亮度**——默认 `0.20/0.20/0.20` 归一化后就是中性白，亮度完全由 `lv` 决定。screen 混合让亮处自动少加、暗处仍能抬起。

## 文件结构

```
shaders/
├── shaders.properties        # 只声明游戏内滑块；不写 oldLighting
├── lang/zh_cn.lang / en_us.lang  # 滑块名称和提示
├── final.vsh / final.fsh     # 唯一实际逻辑，在 final.fsh
└── lib/handlight_settings.glsl  # 滑块默认值和取值范围
set-color.ps1 / set-color.cmd     # 输入色号，自动写入 RGB 并同步游戏目录/zip
```

`shaders.properties` 里**不写** `oldLighting`：本包没有任何 `gbuffers_*` 几何程序，没有代码读 `gl_Color`，原版方向面光是 Iris 默认渲染自带的，写它不会改变画面。`oldHandLight=false` 让主副手亮度分别传给 shader（取较大值）；`screen` / `sliders` 只暴露手光选项。没有使用 `dynamicHandLight`——那是 OptiFine 遗留项，当前 Iris 指令表里没有，写的也会被忽略。

## 安装

1. 下载或克隆本仓库
2. 将仓库内容（含 `shaders/` 文件夹）放到 `.minecraft/shaderpacks/HandLightOnly/`，或使用 Releases 里的 zip
3. 游戏内：视频设置 → 光影 → 选择 `HandLightOnly`
4. 游戏内：视频设置 → 光影 → Shader Pack Settings，直接拖滑块调亮度和光色；或者用下面的色号脚本一步设定光色
5. 修改 shader 文件后按 `R` 重载

> **打包注意**：zip 里 `shaders/` 必须在**根目录**（条目形如 `shaders/final.fsh`）。
> 不要把整个 `HandLightOnly/` 文件夹压进去，否则 Iris 找不到根目录的 `shaders/`，会报
> `Pack "..." is not valid! Can't load it.` 并回退到无光影。

适用于 Minecraft 1.21.1 + NeoForge + Iris / Sodium。

## 调参

游戏内 **Shader Pack Settings** 直接调这 5 个滑块；默认值也写在 `shaders/lib/handlight_settings.glsl` 里，改文件后按 `R` 重载。

| 选项 | 默认 | 范围 / 说明 |
|---|---|---|
| `HL_STRENGTH` | `1.00` | 亮度倍率，`1.00` = 与手持光级一致；0.00~3.00 步长 0.10，`0` 等于关闭手光 |
| `HL_FALLOFF` | `0.11` | 距离衰减，越大光圈越小 |
| `HL_TINT_R` | `0.20` | 红色光量，0.00~1.00 步长 0.01；`0.20` 最接近原版 |
| `HL_TINT_G` | `0.20` | 绿色光量，0.00~1.00 步长 0.01；`0.20` 最接近原版 |
| `HL_TINT_B` | `0.20` | 蓝色光量，0.00~1.00 步长 0.01；`0.20` 最接近原版 |

默认光色是中性灰 `0.20 / 0.20 / 0.20`（色号 `#333333`），归一化后就是中性白，只管色相不管亮度；`HL_STRENGTH` 默认 `1.00`，直接对应手持光级，上限保留 `3.00`。模组方块如果返回高于 15 的亮度，会被夹到 15，避免近处爆亮。

**注意**：Iris 会记住你在 Shader Pack Settings 里拖过的滑块值，可能覆盖源码默认值。如果改完源码重载后画面仍像旧参数，先点 **Reset** / 重新选择光影，或清掉该包保存的 shader options。

### 直接输入色号

Iris 的 Shader Pack Settings 只支持预设数值的滑块/选项，没有文本框，所以打包了一个小脚本把色号翻译成 RGB 默认值：

```powershell
.\set-color.cmd "#66CCFF"
```

也支持 `66CCFF`、`0x66CCFF`、`#ABC`；不带参数运行会提示输入。脚本会：

1. 把 `#RRGGBB` 转成 `0.00~1.00` 三个通道，写进 `shaders/lib/handlight_settings.glsl`
2. 同步到 `.minecraft/shaderpacks/HandLightOnly/`
3. 重建 `versions\1.21.1-NeoForge\shaderpacks\HandLightOnly.zip`

然后进游戏按 `R` 重载。**注意**：如果之前在 Shader Pack Settings 里手动改过 RGB 滑块，滑块值会覆盖文件默认值，需要先点 Reset / 重新选择光影。脚本只改文件，不碰世界和游戏配置。

`HL_DEBUG` 只改文件、不进游戏菜单：改成 `1` 后画面灰度显示 `heldBlockLightValue / 15`，用来确认 uniform 在 final 里有值。

## 已知取舍

- 点光源没有遮挡计算，光会轻微穿薄墙；靠衰减半径把破绽藏住
- 没有表面法线项，掠射角物体也会亮；但光源在相机处，可见正面基本都朝向它，影响很小
- `depthtex2` 不含透明物，水/玻璃表面不会被手光照到
- 只有亮度信息，无法按方块区分颜色，所以萤石/火把/海晶灯共用同一个默认中性色
- 纯视觉，不改变世界真实光照等级
