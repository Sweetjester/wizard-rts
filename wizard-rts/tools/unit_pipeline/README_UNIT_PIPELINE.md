# Unit Pipeline

This pipeline turns one unit YAML file plus one concept image into a first-pass generated unit folder for the Godot project.

It is meant for rough playable iteration, not final art. Meshy provides the rough model, Blender normalizes it into a predictable GLB, and Godot creates generated scene/data/report files that can be manually improved later.

The pipeline now supports style profiles. A unit spec can set `visual.style_profile` to a JSON profile that controls Blender cleanup, material remapping, outline proxies, and the painterly/NPR target. The current KON target is:

```text
tools/unit_pipeline/style_profiles/darkest_dungeon_2_like_kon.json
```

## Windows Setup

```powershell
winget install Python.Python.3.11
winget install BlenderFoundation.Blender
winget install GodotEngine.GodotEngine
winget install Git.Git
```

Then:

```powershell
python -m venv .venv
.\.venv\Scripts\activate
pip install -r tools\unit_pipeline\requirements.txt
copy .env.example .env
notepad .env
```

Fill in:

```dotenv
MESHY_API_KEY=
BLENDER_PATH=C:\Program Files\Blender Foundation\Blender 4.3\blender.exe
GODOT_PATH=C:\Program Files\Godot\Godot_v4.exe
```

## Run

Put the concept image at:

```text
art\concepts\oaven\oaven_spear.png
```

Validate without calling Meshy/Blender/Godot:

```powershell
python tools\unit_pipeline\create_unit.py units\specs\oaven_spear.yaml --dry-run
```

Create the unit:

```powershell
python tools\unit_pipeline\create_unit.py units\specs\oaven_spear.yaml
```

Reuse an existing raw model in `art\generated_models\<unit_id>\`:

```powershell
python tools\unit_pipeline\create_unit.py units\specs\oaven_spear.yaml --skip-meshy
```

This is the fastest way to restyle a current Meshy model after changing the Blender processing or style profile.

Overwrite generated files:

```powershell
python tools\unit_pipeline\create_unit.py units\specs\oaven_spear.yaml --force
```

## Outputs

- `art/generated_models/<unit_id>/`: raw Meshy files and task metadata
- `art/processed_models/<unit_id>/<unit_id>.glb`: Blender-normalized model
- `game/units/generated/<unit_id>/<unit_id>.tscn`: generated Godot unit scene
- `game/units/generated/<unit_id>/<unit_id>.gd`: generated gameplay wrapper
- `game/data/units/<unit_id>.tres`: generated unit data
- `game/units/generated/<unit_id>/IMPORT_REPORT.md`: import report

For projectile units, the Godot batch step also creates:

- `game/projectiles/generated/<projectile_id>/<projectile_id>.tscn`
- `game/projectiles/generated/<projectile_id>/<projectile_id>.gd`

## Notes

- The existing project unit runtime is currently 2D (`RTSUnit`). Generated units are isolated under `game/units/generated` as `Node3D` first-pass assets with TODO bridge points.
- Meshy Image to 3D accepts a public image URL or a base64 data URI. This pipeline sends the local concept image as a data URI using the API endpoint `POST /openapi/v1/image-to-3d`.
- Meshy is still mostly driven by the input concept image. For the Darkest-Dungeon-like target, use clean orthographic or three-quarter concept sheets with a strong silhouette, dark painterly values, no UI, no text, no large presentation base, and controlled KON cyan emissive accents.
- Blender discards imported AI materials when the style profile requests it, then remaps the unit to the project material palette. This is currently the main style enforcement step.
- Blender creates placeholder actions named `idle`, `move`, `attack`, and `death` when generated art does not provide usable animations.
- Generated files are protected from overwrites unless `--force` is passed.
