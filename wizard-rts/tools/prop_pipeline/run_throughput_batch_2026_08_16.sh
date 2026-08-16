#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/../.."

SPECS=(
  mushroom_blocker_d
  mushroom_blocker_e
  mushroom_cluster_large_c
  mushroom_cluster_large_d
  mushroom_cluster_small_c
  mushroom_cluster_small_d
  glowing_mushroom_ring_hero_c
  rock_blocker_c
  rock_blocker_d
  rock_moss_cluster_c
  rock_moss_cluster_d
  root_blocker_d
  root_blocker_e
  root_wall_hero_c
  ruin_prop_d
  ruin_prop_e
  ruined_shrine_d
  ruined_shrine_e
  shrine_prop_d
  shrine_prop_e
  corrupted_altar_d
  broken_stone_arch_d
  torch_prop_d
  torch_prop_e
  torch_or_soul_light_d
  bone_decor_d
  dead_tree_spike_c
  road_decor_d
  road_edge_roots_d
  water_edge_decor_d
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
