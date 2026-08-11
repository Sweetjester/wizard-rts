#!/usr/bin/env bash
# Runs create_prop.py sequentially for a fixed batch of new specs, continuing past
# individual failures, and writes a pass/fail summary at the end.
set -u
cd "$(dirname "$0")/../.."

SPECS=(
  ancient_tree_hero_b
  root_wall_hero_b
  glowing_mushroom_ring_hero_b
  rock_blocker_b
  rock_moss_cluster_b
  mushroom_cluster_small_b
  mushroom_cluster_large_b
  twisted_root_blocker_b
  dead_tree_spike_b
  tree_blocker_c
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
