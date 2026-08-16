#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/../.."

SPECS=(
  bone_decor_e
  bone_decor_f
  broken_stone_arch_e
  broken_stone_arch_f
  corrupted_altar_e
  corrupted_altar_f
  dead_tree_spike_d
  dead_tree_spike_e
  glowing_mushroom_ring_hero_d
  glowing_mushroom_ring_hero_e
  road_decor_e
  road_decor_f
  road_edge_roots_e
  road_edge_roots_f
  root_wall_hero_d
  root_wall_hero_e
  torch_or_soul_light_e
  torch_or_soul_light_f
  water_edge_decor_e
  water_edge_decor_f
  mushroom_blocker_f
  mushroom_cluster_large_e
  mushroom_cluster_small_e
  rock_blocker_e
  rock_moss_cluster_e
  root_blocker_f
  ruined_shrine_f
  ruin_prop_f
  shrine_prop_f
  torch_prop_f
  cliff_side_g
  cliff_corner_g
  ramp_mesh_g
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
