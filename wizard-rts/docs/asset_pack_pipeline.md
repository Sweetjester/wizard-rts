# Asset Pack Import Pipeline

The map generator should not know which art pack is active. It should keep asking for stable terrain roles such as `low_ground`, `path`, `water`, `cliff`, and `wizard_tower_wall`.

The importer adapts an external pack into the filenames already referenced by `assets/tiles/voxel/voxel_tileset.tres`. Because the filenames stay stable, Godot and `MapGenerator._load_tiles()` pick up the new graphics without map-generation code changes.

## Current Adapter

`tools/import_asset_pack.ps1` currently supports:

- `tiny-swords`: reads `Tiny Swords/Tiny Swords (Free Pack)`.

It produces:

- `assets/imported/tiny_swords/manifest.json`: source pack analysis.
- `assets/imported/tiny_swords/last_apply.json`: generated asset list and backup folder.
- `assets/imported/tiny_swords/backups/<timestamp>/...`: original files before replacement.
- `assets/tiles/voxel/*_vm_*.png`: generated terrain tiles used by the map generator.
- `assets/buildings/kon/*.png`: generated building stand-ins from Tiny Swords.

Raw source packs should include a `.gdignore` file so Godot does not import vendor folders, macOS metadata, or unused source art. The game only consumes the generated files under `assets/`.

## Commands

Analyze only:

```powershell
powershell.exe -ExecutionPolicy Bypass -File tools\import_asset_pack.ps1 -Pack tiny-swords -Mode analyze
```

Analyze and apply:

```powershell
powershell.exe -ExecutionPolicy Bypass -File tools\import_asset_pack.ps1 -Pack tiny-swords -Mode all
```

Apply without creating a backup:

```powershell
powershell.exe -ExecutionPolicy Bypass -File tools\import_asset_pack.ps1 -Pack tiny-swords -Mode apply -NoBackup
```

## Adding Another Pack

Add a pack adapter in `tools/import_asset_pack.ps1` that maps source files to these stable roles:

- `low_ground_vm`
- `mid_ground_vm`
- `high_ground_vm`
- `path_vm`
- `path_slope_vm`
- `water_vm`
- `cliff_vm`
- `foliage_vm`
- `economy_plot_vm`
- `ruin_floor_vm`
- `bandit_floor_vm`
- `bandit_wall_vm`
- `wizard_tower_floor_vm`
- `wizard_tower_wall_vm`

Keep generated terrain PNGs at `111x128` unless the TileSet is deliberately rebuilt.
