# Remove BG Skill

[中文](README.md) | [English](README.en.md)

![Codex Skill](https://img.shields.io/badge/Codex-Skill-111827)
![Claude Compatible](https://img.shields.io/badge/Claude-Compatible-6B46C1)
![Transparent PNG](https://img.shields.io/badge/Output-Transparent%20PNG-00B96B)
![Sprite Ready](https://img.shields.io/badge/Sprite-Ready-7B61FF)
![Local First](https://img.shields.io/badge/Privacy-Local%20First-success)
![Language](https://img.shields.io/badge/Language-ZH%20%2B%20EN-blue)
![Status](https://img.shields.io/badge/Status-Active-success)

`remove-bg` is a local background-removal skill for Codex and Claude Code. It creates transparent PNG cutouts and saves results beside the source images by default.

The skill has two standard paths: a deterministic PowerShell workflow for game sprites, pixel art, icons, and flat black backgrounds; and a `rembg` workflow for natural photos, portraits, products, and complex edges.

---

## Preview

### Sprite Background Removal

![Remove BG sprite checker preview](assets/intro-01-sprite-checker.png)

The checkerboard contact sheet makes transparent-background QA quick and visual.

---

## Use Cases

Good trigger examples:

```text
Remove the black background from these game frames and save the results beside the source files.
```

```text
Remove the background and output a transparent PNG.
```

```text
Batch cut out these images, similar to remove.bg.
```

Not a fit:

- Creative background replacement only.
- Resize, crop, or compression only.
- AI redrawing where preserving the original subject is not required.

---

## Requirements

### Sprites and Pixel Art

Windows PowerShell only. No Python and no network required.

### Natural Photos and Complex Backgrounds

Install Python dependencies:

```powershell
py -3 -m pip install -r .\remove-bg\requirements.txt
```

The first `rembg` run may download model weights.

---

## Install

### Agent URL Install

Ask Codex or Claude Code:

```text
Install this skill: https://github.com/VioletScar-Hui/Removebg/tree/main/remove-bg
```

Restart Codex or Claude Code after installation.

### Codex

```powershell
$repoPath = "$env:USERPROFILE\.agents\skill-repos\Removebg"
$skillPath = "$env:USERPROFILE\.agents\skills\remove-bg"
New-Item -ItemType Directory -Force -Path (Split-Path $repoPath) | Out-Null
if (Test-Path "$repoPath\.git") {
  Set-Location $repoPath
  git pull --ff-only
} else {
  git clone https://github.com/VioletScar-Hui/Removebg.git $repoPath
}
New-Item -ItemType Directory -Force -Path $skillPath | Out-Null
Copy-Item -Path "$repoPath\remove-bg\*" -Destination $skillPath -Recurse -Force
```

### Claude Code

```powershell
$repoPath = "$env:USERPROFILE\.claude\skill-repos\Removebg"
$skillPath = "$env:USERPROFILE\.claude\skills\remove-bg"
New-Item -ItemType Directory -Force -Path (Split-Path $repoPath) | Out-Null
if (Test-Path "$repoPath\.git") {
  Set-Location $repoPath
  git pull --ff-only
} else {
  git clone https://github.com/VioletScar-Hui/Removebg.git $repoPath
}
New-Item -ItemType Directory -Force -Path $skillPath | Out-Null
Copy-Item -Path "$repoPath\remove-bg\*" -Destination $skillPath -Recurse -Force
```

---

## Standard Run

For game frames or pixel art:

```powershell
$files = @(
  "C:\path\frame_00.png",
  "C:\path\frame_01.png"
)
.\remove-bg\scripts\remove_sprite_bg.ps1 -InputPath $files
```

For photos:

```powershell
py -3 .\remove-bg\scripts\remove_bg.py "C:\path\input.jpg" --alpha-matting
```

---

## Acceptance Criteria

Before reporting completion, confirm that:

- the background is transparent
- the foreground subject and intended effects remain visible
- there are no obvious black rectangles, stray fragments, halos, or clipped subject parts
- original files remain available

---

## Repository Structure

```text
Removebg/
  README.md
  README.en.md
  CHANGELOG.md
  assets/
  remove-bg/
    README.md
    SKILL.md
    requirements.txt
    scripts/
    tests/
    evals/
```
