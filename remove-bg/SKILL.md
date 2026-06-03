---
name: remove-bg
description: Use when the user asks to remove backgrounds from one or more images and save results beside the source image, including remove.bg-like cutouts, transparent PNGs, alpha channel output, sprite/game-frame background removal, product-photo cleanup, portrait cutout, 抠图, 扣图, 去背景, or 透明背景.
---

# Remove BG

## Overview

Create remove.bg-like transparent PNG cutouts from local images. Prefer local processing so private images stay on the machine. By default, save new PNG files beside the source images using `_removebg.png` and keep originals unchanged.

## Standard Workflow

1. Locate the image file(s). If the user only attached previews, ask for the local file paths.
2. Classify the input:
   - Use the sprite workflow for pixel art, game frames, icons, and flat pure/near-black backgrounds.
   - Use the photo workflow for natural photos, portraits, products on complex backgrounds, and soft hair/fabric edges.
3. Save outputs beside the source images unless the user names a different folder.
4. Verify that the background is transparent and the subject is preserved before reporting completion.

## Sprite Workflow

Use this path for game sprites and animation frames like `frame_00.png`.

```powershell
$files = @(
  "C:\path\frame_00.png",
  "C:\path\frame_01.png"
)
.\scripts\remove_sprite_bg.ps1 -InputPath $files
```

The wrapper performs the full standard operation:

- remove large pure/near-black background components
- keep the original image untouched
- save `_removebg.png` files in the source directory
- clean isolated crop/spritesheet fragments
- generate `remove-bg-checker-contact.png` for visual QA
- print transparent/opaque pixel counts for verification

Useful options:

```powershell
.\scripts\remove_sprite_bg.ps1 -InputPath $files -Threshold 8 -MinBackgroundComponent 500 -KeepDistance 48
.\scripts\remove_sprite_bg.ps1 -InputPath $files -OutputDirectory "C:\path\out"
.\scripts\remove_sprite_bg.ps1 -InputPath $files -SkipCleanup
```

Adjust `Threshold` upward only when the background is near-black rather than pure black. If dark clothing or hair is being removed, lower `Threshold` or increase `MinBackgroundComponent`.

## Photo Workflow

Use this path for real photos and complex backgrounds.

```powershell
py -3 .\scripts\remove_bg.py "C:\path\input.jpg" --alpha-matting
```

Batch a folder:

```powershell
py -3 .\scripts\remove_bg.py "C:\path\photos" --recursive --alpha-matting
```

If dependencies are missing:

```powershell
py -3 -m pip install -r .\requirements.txt
```

On Windows, `python.exe` may point to the Microsoft Store placeholder. Prefer `py -3` when available. The first real `rembg` run may download model weights; request network approval when needed.

## Quality Bar

The result is acceptable only when:

- the original background is transparent
- the foreground subject and intended effects remain visible
- no obvious black rectangles, halos, neighboring-frame fragments, or cut-off subject parts remain
- the original source files are still available

For sprite work, inspect the generated checker contact sheet. For photo work, inspect at least one output image directly.

## Common Mistakes

- Do not overwrite a JPG source with a transparent result; JPG cannot store alpha.
- Do not remove every black pixel in sprite art; characters often contain black outlines, hair, clothes, and shadows.
- Do not use AI image editing for game frames unless the user wants creative reconstruction; it can alter pixel art.
- Do not claim completion from file creation alone. Check alpha output or a checkerboard preview.
