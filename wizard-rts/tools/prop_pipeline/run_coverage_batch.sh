#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/../.."

SPECS=(
  mushroom_blocker_c
  root_blocker_c
  ruin_prop_c
  shrine_prop_c
  torch_prop_c
  road_decor_c
  water_edge_decor_c
  ruined_shrine_c
  corrupted_altar_c
  broken_stone_arch_c
  torch_or_soul_light_c
  bone_decor_c
  road_edge_roots_c
  cliff_side_c
  cliff_corner_c
  ramp_mesh_c
)

RESULTS=()
for spec in "${SPECS[@]}"; do
  echo "===================================================="
  echo "[batch] starting $spec at $(date)"
  echo "===================================================="
  if python tools/prop_pipeline/create_prop.py "props/specs/$spec.yaml"; then
    RESULTS+=("OK   $spec")
  else
    RESULTS+=("FAIL $spec")
  fi
done

echo "===================================================="
echo "[batch] summary"
echo "===================================================="
for line in "${RESULTS[@]}"; do
  echo "$line"
done
