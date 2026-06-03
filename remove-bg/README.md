# Remove BG Skill

![Codex Skill](https://img.shields.io/badge/Codex-Skill-111827)
![Claude Compatible](https://img.shields.io/badge/Claude-Compatible-6B46C1)
![Transparent PNG](https://img.shields.io/badge/Output-Transparent%20PNG-00B96B)
![Sprite Ready](https://img.shields.io/badge/Sprite-Ready-7B61FF)
![Language](https://img.shields.io/badge/Language-ZH%20%2B%20EN-blue)
![Status](https://img.shields.io/badge/Status-Active-success)

`remove-bg` 是一个面向 Codex 和 Claude Code 的本地抠图 Skill。它用于把图片背景移除并输出透明 PNG，默认把结果保存到源图片所在目录，适合游戏帧、像素素材、商品图、人像和需要类似 remove.bg 效果的场景。

它的核心原则是：原图不覆盖，隐私不上传，先走确定性本地流程；只有自然照片或复杂背景才使用 `rembg` 模型路径。

---

## 适用场景

适合触发的请求：

```text
把这些游戏帧的黑色背景扣掉，保存到原地址
```

```text
帮我给这张图去背景，输出透明 PNG
```

```text
批量抠图，效果参考 remove.bg
```

不适合触发的请求：

- 只是想换一个创意背景。
- 只是压缩、裁剪、改尺寸。
- 用户允许 AI 重绘整张图，而不是保留原始主体。

---

## 前置条件

### 像素图 / 游戏帧

Windows PowerShell 即可，不需要 Python，也不需要联网。

### 自然照片 / 复杂背景

需要 Python 和 `rembg`：

```powershell
py -3 -m pip install -r .\requirements.txt
```

首次运行 `rembg` 可能需要下载模型权重。

---

## 标准流程

### 游戏帧、像素图、纯黑背景

```powershell
$files = @(
  "C:\path\frame_00.png",
  "C:\path\frame_01.png"
)
.\scripts\remove_sprite_bg.ps1 -InputPath $files
```

默认会：

1. 删除大面积纯黑或近黑背景。
2. 保留角色黑色描边、头发、衣服和阴影。
3. 清理孤立的裁切碎片。
4. 在源目录保存 `*_removebg.png`。
5. 生成 `remove-bg-checker-contact.png` 用于棋盘格检查。
6. 输出每张图的透明像素和不透明像素统计。

常用参数：

```powershell
.\scripts\remove_sprite_bg.ps1 -InputPath $files -Threshold 8 -MinBackgroundComponent 500 -KeepDistance 48
.\scripts\remove_sprite_bg.ps1 -InputPath $files -OutputDirectory "C:\path\out"
.\scripts\remove_sprite_bg.ps1 -InputPath $files -SkipCleanup
```

### 自然照片、人像、商品图

```powershell
py -3 .\scripts\remove_bg.py "C:\path\input.jpg" --alpha-matting
```

批量处理：

```powershell
py -3 .\scripts\remove_bg.py "C:\path\photos" --recursive --alpha-matting
```

---

## 验收标准

处理完成前必须确认：

- 背景已经透明。
- 主体和需要保留的特效仍然可见。
- 没有明显黑色矩形、残留碎片或主体被切掉。
- 原始文件仍然存在。

像素图优先检查 `remove-bg-checker-contact.png`。照片至少打开一张输出图检查边缘。

---

## 安装

### Codex

```powershell
$skillPath = "$env:USERPROFILE\.agents\skills\remove-bg"
New-Item -ItemType Directory -Force -Path $skillPath | Out-Null
Copy-Item -Path ".\remove-bg\*" -Destination $skillPath -Recurse -Force
```

### Claude Code

```powershell
$skillPath = "$env:USERPROFILE\.claude\skills\remove-bg"
New-Item -ItemType Directory -Force -Path $skillPath | Out-Null
Copy-Item -Path ".\remove-bg\*" -Destination $skillPath -Recurse -Force
```

安装后重启 Codex 或 Claude Code，让 Skill 索引重新加载。

---

## 仓库结构

```text
Removebg/
  README.md
  remove-bg/
    README.md
    SKILL.md
    requirements.txt
    scripts/
      remove_sprite_bg.ps1
      pixel_black_bg_remove.ps1
      cleanup_isolated_components.ps1
      make_checker_contact.ps1
      remove_bg.py
    tests/
      test_remove_bg.py
    evals/
      evals.json
```

---

## 常见问题

### 为什么不直接删除所有黑色像素？

游戏角色经常有黑色描边、头发、衣服和阴影。直接删除所有黑色会破坏主体。这个 Skill 默认只删除大面积背景连通块，并保留主体内部黑色细节。

### 为什么输出是 PNG？

透明背景需要 alpha 通道，JPG 不能保存透明信息。

### 为什么不覆盖原图？

原图是可回退资产。默认输出 `*_removebg.png`，避免破坏素材工程。
