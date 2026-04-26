# PixelLab Asset Generator

Batch generator for Wizard RTS production assets. It reads `tools/pixellab_asset_manifest.json`, submits enabled asset batches to PixelLab, tracks jobs under `tools/pixellab/jobs`, and saves finished files under `assets/generated/pixellab`.

## Secret Setup

Do not commit API keys. Set your token in the shell before running live API commands:

```powershell
$env:PIXELLAB_API_KEY = "your-pixellab-token"
```

Optional override:

```powershell
$env:PIXELLAB_API_BASE = "https://api.pixellab.ai/v2"
```

## Commands

Launch the local UI:

```powershell
.\tools\run_pixellab_asset_generator.ps1 ui
```

Preview the batch without using credits:

```powershell
.\tools\run_pixellab_asset_generator.ps1 plan
.\tools\run_pixellab_asset_generator.ps1 --max-submit 1 submit --dry-run
```

Check account balance:

```powershell
.\tools\run_pixellab_asset_generator.ps1 balance
```

Submit the manifest:

```powershell
.\tools\run_pixellab_asset_generator.ps1 submit
```

Poll and download finished jobs:

```powershell
.\tools\run_pixellab_asset_generator.ps1 poll
```

Submit and keep polling until done:

```powershell
.\tools\run_pixellab_asset_generator.ps1 run --timeout-minutes 45
```

Use a smaller first spend pass:

```powershell
.\tools\run_pixellab_asset_generator.ps1 --max-submit 3 submit
```

## Manifest Batch Types

- `character_8dir`: 8-direction RTS sprites through `/create-character-with-8-directions`. Nested `animations` are queued after the character completes.
- `character_animation`: animation jobs for an existing PixelLab `character_id`.
- `map_object`: transparent buildings, props, projectiles, and one-off sprite assets through `/generate-image-v2`.
- `image`: flexible image generation for effects, sprite sheets, UI elements, or projectiles.
- `isometric_tile`: single isometric terrain/object tiles through `/create-isometric-tile`.
- `tiles_pro`: multi-tile generation through `/create-tiles-pro`.

Generated outputs are intentionally ignored by git until we decide which assets are production keepers.

## Review Exports

The UI's **Build Review** button copies generated candidates into:

```text
assets/review/pixellab/<review-label>/
  index.html
  _review_summary.json
  01_<batch>/
    <asset>/
      candidates/
      metadata/
      review_status.todo.json
```

This makes it easy to compare candidates, keep notes, and later promote selected files into the real `assets/` folders.
