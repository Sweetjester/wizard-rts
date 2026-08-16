#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/../.."

SPECS=(
  cliff_side_d
  cliff_side_e
  cliff_side_f
  cliff_corner_d
  cliff_corner_e
  cliff_corner_f
  ramp_mesh_d
  ramp_mesh_e
  ramp_mesh_f
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
