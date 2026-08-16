#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/../.."

SPECS=(
  lantern_tree_a
  lantern_tree_b
  lantern_tree_c
  lantern_tree_d
  lantern_tree_e
  lantern_tree_hero_f
  twisted_root_blocker_c
  twisted_root_blocker_d
  base_plot_marker_b
  content_plot_marker_b
  outpost_marker_b
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
