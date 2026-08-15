#!/usr/bin/env bash
# Re-runs Blender processing (only) for every spec, applying the current style profile
# without spending new Meshy credits. Use after a style_profile change.
set -u
cd "$(dirname "$0")/../.."

for spec in props/specs/*.yaml; do
  echo "=== $(basename "$spec") ==="
  python tools/prop_pipeline/create_prop.py "$spec" --skip-meshy || echo "FAILED: $spec"
done
