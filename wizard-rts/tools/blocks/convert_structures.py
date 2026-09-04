"""Convert the authored block-structure YAML into JSON Godot can load at runtime.

Godot has no YAML parser. Every other YAML in this project (props/specs,
units/specs) is consumed by Python tooling and never by the game, so a build
step is the established pattern rather than a new dependency -- see the
2026-09-04 entry in the Decisions Log.

YAML stays the authoring format because it is what the spec was written in and
what a human edits. JSON is the build artefact.

Usage:
    python tools/blocks/convert_structures.py

Reads  data/block_structures/structures.yaml
Writes resources/block_structures/structures.json

The converter also VALIDATES, because a malformed structure should fail here
with a readable message rather than as a confusing nav bug three systems later.
It reports problems without repairing them: the pack's own instruction is to
preserve the data and report ambiguity rather than invent gameplay rules.
"""

import json
import os
import sys

import yaml

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC_DIR = os.path.join(ROOT, "data", "block_structures")
DST = os.path.join(ROOT, "resources", "block_structures", "structures.json")

# Schema 1.1 renamed several fields and moved from a `structures:` map to a
# single `structure:`. Both are supported rather than migrating the 1.0 pack,
# because that pack is the reference data the original test cases were written
# against and rewriting it would quietly invalidate them.
FIELD_ALIASES = {
    "navigation": "nav",          # 1.1 blocks say `navigation:`
    "traversal_links": "links",   # 1.1 calls them traversal_links
}
CLASS_ALIASES = {
    "can_pass_gates": "can_pass_open_gates",
}


def normalise_structure(structure):
    """Rewrites a 1.1 structure in place into the shape the runtime expects."""
    for block in structure.get("blocks", []):
        for old_key, new_key in FIELD_ALIASES.items():
            if old_key in block:
                block[new_key] = block.pop(old_key)
    if "traversal_links" in structure:
        structure["links"] = structure.pop("traversal_links")
    # 1.1 nests dimensions as a mapping; the runtime wants [x, y, z].
    dims = structure.get("dimensions")
    if isinstance(dims, dict):
        structure["dimensions"] = [int(dims["x"]), int(dims["y"]), int(dims["z"])]
    # `sockets` was renamed and moved under procedural_generation.
    generation = structure.get("procedural_generation", {})
    if "connection_sockets" in generation:
        structure["sockets"] = generation["connection_sockets"]
    # Gates carry their own default state. Recorded on the structure so the
    # runtime can start them closed without the caller having to know.
    defaults = {}
    for gate in structure.get("gates", []):
        defaults[str(gate.get("state_key", ""))] = str(gate.get("default_state", "closed")) == "open"
    if defaults:
        structure["gate_defaults"] = defaults
    return structure


def normalise_classes(classes):
    for data in classes.values():
        if not isinstance(data, dict):
            continue
        for old_key, new_key in CLASS_ALIASES.items():
            if old_key in data:
                data[new_key] = data.pop(old_key)
    return classes


def load_all():
    """Merges every YAML in the source directory into one document."""
    merged = {"structures": {}, "unit_classes": {}, "nav_types": {}, "materials": {}, "world": {}}
    for name in sorted(os.listdir(SRC_DIR)):
        if not name.endswith((".yaml", ".yml")):
            continue
        with open(os.path.join(SRC_DIR, name), "r", encoding="utf-8") as handle:
            data = yaml.safe_load(handle) or {}
        merged["world"].update(data.get("world", {}))
        merged["world"].update(data.get("world_rules", {}))
        merged["nav_types"].update(data.get("nav_types", {}))
        merged["materials"].update(data.get("materials", {}))
        merged["unit_classes"].update(normalise_classes(data.get("unit_classes", {})))
        # 1.0: a map of many structures.
        for sid, structure in (data.get("structures") or {}).items():
            merged["structures"][sid] = normalise_structure(structure)
        # 1.1: one structure, carrying its own classes and materials.
        single = data.get("structure")
        if single:
            merged["materials"].update(single.get("materials", {}))
            merged["unit_classes"].update(normalise_classes(single.get("unit_classes", {})))
            merged["structures"][str(single["id"])] = normalise_structure(single)
    return merged


def as_range(value):
    """A YAML range is either [min, max] inclusive, or a bare int meaning [n, n]."""
    if isinstance(value, list):
        return int(value[0]), int(value[1])
    return int(value), int(value)


def region_bounds(region):
    return {
        "x": as_range(region["x"]),
        "y": as_range(region["y"]),
        "z": as_range(region["z"]),
    }


def region_cell_count(region):
    b = region_bounds(region)
    return (
        (b["x"][1] - b["x"][0] + 1)
        * (b["y"][1] - b["y"][0] + 1)
        * (b["z"][1] - b["z"][0] + 1)
    )


def validate(data):
    """Returns a list of human-readable problems. Never mutates the data."""
    problems = []
    structures = data.get("structures", {})
    for sid, structure in structures.items():
        dims = structure.get("dimensions")
        if not dims or len(dims) != 3:
            problems.append("%s: dimensions must be [x, y, z]" % sid)
            continue
        size_x, size_y, size_z = (int(v) for v in dims)

        # Nav regions may legitimately sit one level ABOVE the highest block --
        # a unit stands in the empty cell on top of a solid one. So the height
        # check allows y == size_y, and only flags what is further out than that.
        for kind, entries in (("block", structure.get("blocks", [])),
                              ("nav_region", structure.get("nav_regions", []))):
            for entry in entries:
                region = entry.get("region")
                if region is None:
                    problems.append("%s: %s entry has no region" % (sid, kind))
                    continue
                b = region_bounds(region)
                allowance = 1 if kind == "nav_region" else 0
                if b["x"][0] < 0 or b["x"][1] >= size_x:
                    problems.append("%s/%s %s: x %s outside 0..%d"
                                    % (sid, kind, entry.get("id", "?"), b["x"], size_x - 1))
                if b["z"][0] < 0 or b["z"][1] >= size_z:
                    problems.append("%s/%s %s: z %s outside 0..%d"
                                    % (sid, kind, entry.get("id", "?"), b["z"], size_z - 1))
                if b["y"][1] >= size_y + allowance:
                    problems.append("%s/%s %s: y %s exceeds declared height %d%s"
                                    % (sid, kind, entry.get("id", "?"), b["y"], size_y,
                                       " (+1 standing allowance)" if allowance else ""))
                if b["y"][0] < 0:
                    problems.append("%s/%s %s: y %s is negative, but the origin rule says "
                                    "the local origin is the minimum corner"
                                    % (sid, kind, entry.get("id", "?"), b["y"]))
        # Links must name endpoints, and a link that goes nowhere is a typo.
        for link in structure.get("links", []):
            for end in ("from", "to"):
                if end not in link or len(link[end]) != 3:
                    problems.append("%s/link %s: %s must be [x, y, z]"
                                    % (sid, link.get("id", "?"), end))
            if link.get("from") == link.get("to"):
                problems.append("%s/link %s: from and to are the same cell"
                                % (sid, link.get("id", "?")))
    return problems


def main():
    data = load_all()
    problems = validate(data)

    # Precompute what the runtime would otherwise recompute on every load.
    for sid, structure in data.get("structures", {}).items():
        structure["id"] = sid
        structure["block_cell_count"] = sum(
            region_cell_count(b["region"]) for b in structure.get("blocks", []))
        structure["nav_cell_count"] = sum(
            region_cell_count(n["region"]) for n in structure.get("nav_regions", []))

    # 1.1 introduces FLOOR_LINK (a horizontal connection between floors that do
    # not touch, like a balcony reached across a gap). Declared here rather than
    # in the data so both schema versions resolve against one table.
    data.setdefault("nav_types", {}).setdefault("FLOOR_LINK", {"walkable": False, "link_only": True})

    data["_generated_by"] = "tools/blocks/convert_structures.py"
    data["_schema_problems"] = problems

    os.makedirs(os.path.dirname(DST), exist_ok=True)
    with open(DST, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(data, handle, indent="\t", sort_keys=True)
        handle.write("\n")

    print("wrote %s" % os.path.relpath(DST, ROOT))
    print("structures: %d" % len(data.get("structures", {})))
    if problems:
        print("\n%d schema problem(s) -- reported, NOT repaired:" % len(problems))
        for problem in problems:
            print("  - %s" % problem)
    else:
        print("no schema problems")
    return 0


if __name__ == "__main__":
    sys.exit(main())
