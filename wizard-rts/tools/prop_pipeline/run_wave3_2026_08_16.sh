#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/../.."

SPECS=(
  twisted_root_blocker_e
  mushroom_blocker_g
  mushroom_cluster_small_f
  mushroom_cluster_large_f
  rock_blocker_f
  rock_moss_cluster_f
  root_blocker_g
  torch_prop_g
  torch_or_soul_light_g
  road_decor_g
  road_edge_roots_g
  water_edge_decor_g
  bone_decor_g
  dead_tree_spike_f
  cliff_side_h
  cliff_corner_h
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
