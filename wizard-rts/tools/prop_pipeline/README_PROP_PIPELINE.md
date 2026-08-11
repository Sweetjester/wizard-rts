# Prop Pipeline

This pipeline turns one prop YAML file with a Meshy text prompt into a first-pass static GLB for the Godot project.

It mirrors the unit pipeline structure, but uses Meshy Text to 3D preview/refine instead of Image to 3D. No concept-art image is required. Blender normalizes the generated mesh, applies the prop style profile, creates an outline proxy when requested, and the orchestration script registers the runtime GLB in the Dark Forest Frontier V2 asset pack.

The current prop style profile is:

```text
tools/prop_pipeline/style_profiles/dark_forest_frontier_v2_props.json
```

## Setup

Use the same Python environment and `.env` conventions as the unit pipeline:

```powershell
python -m venv .venv
.\.venv\Scripts\activate
pip install -r tools\unit_pipeline\requirements.txt
```

Fill in:

```dotenv
MESHY_API_KEY=
BLENDER_PATH=C:\Program Files\Blender Foundation\Blender 4.3\blender.exe
```

## Run

Validate without calling Meshy or Blender:

```powershell
python tools\prop_pipeline\create_prop.py props\specs\base_plot_marker.yaml --dry-run
```

Create a prop:

```powershell
python tools\prop_pipeline\create_prop.py props\specs\base_plot_marker.yaml
```

Reuse an existing raw model in `art\generated_props\<prop_id>\`:

```powershell
python tools\prop_pipeline\create_prop.py props\specs\base_plot_marker.yaml --skip-meshy
```

This is the fastest way to restyle a current Meshy model after changing Blender processing or the style profile.

## Outputs

- `art/generated_props/<prop_id>/`: raw Meshy GLB plus preview/refine task metadata
- `art/processed_props/<prop_id>/<prop_id>.glb`: Blender-normalized processed GLB
- `assets_game/props/<folder>/dark_forest_frontier_v2/df_v2_<prop_id>_a.glb`: Godot runtime GLB, `<folder>` chosen from the prop's `category` (trees/roots/mushrooms/rocks/ruins/decor/plot_markers — see `CATEGORY_RUNTIME_FOLDER` in `create_prop.py`)
- `resources/asset_packs/dark_forest_frontier_v2_asset_pack.json`: registered `asset_3d_categories` entry
- `art/processed_props/<prop_id>/pipeline_report.json`: pipeline report

## Notes

- Text prompts are read from `visual.prompt`; `visual.negative_prompt` is sent to Meshy when present.
- Meshy preview prompts are compacted to the documented 600-character limit.
- Ground marker specs use `placement.pivot: tile_center_at_top_surface`, matching `BLENDER_EXPORT_GUIDE.md`.
- Props are static assets. The Blender step does not create rigging or placeholder animation actions.
- `model.source: image_to_3d` is also supported: set a top-level `concept_art_path` pointing at a reference image (a cropped, mostly-isolated silhouette works far better than a busy scene) and Meshy's Image to 3D endpoint is used instead of Text to 3D preview/refine.
