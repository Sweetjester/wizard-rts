"""Adapter for the COMPOSITION schema (Kon's Arcane Citadel and friends).

This is a third authoring shape, and it is genuinely a different model rather
than a rename of the previous ones:

  * Blocks are `origin` + `size`, not inclusive min/max ranges.
  * Nav regions are POLYGONS on a plane, and may carry holes, may be assembled
    from named visual decks, may be generated from visual block ids at listed
    levels, or may be a volume.
  * Traversal links connect REGIONS to REGIONS, not cell to cell.
  * The structure instances prefabs -- including a structure authored in an
    earlier schema -- with a Y rotation.

Rather than push all of that into the runtime, it is flattened here into the
one internal shape the engine already understands: inclusive block regions,
rectangular nav regions, and links with concrete cell endpoints. The runtime
stays simple and every schema meets it in the build step.

Everything this adapter INFERS rather than reads is reported, because the
standing rule on these specs is to surface ambiguity rather than invent
gameplay quietly.
"""

import os

import yaml

# Material roles in the composition schema are visual-only names. They all
# collide except the ones a gate or a clear volume carves out.
ROLE_COLLISION = {
    "gate": "conditional",
}


def _rect_from_origin_size(origin, size):
    """origin+size -> the inclusive region the rest of the pipeline speaks."""
    return {
        "x": [int(origin[0]), int(origin[0]) + int(size[0]) - 1],
        "y": [int(origin[1]), int(origin[1]) + int(size[1]) - 1],
        "z": [int(origin[2]), int(origin[2]) + int(size[2]) - 1],
    }


def _polygon_bounds(polygon):
    """Axis-aligned bounds of a polygon. Every polygon in this spec is a
    rectangle; a non-rectangular one is reported rather than approximated
    silently, because quietly turning an L-shape into its bounding box would
    hand units floor that was never authored."""
    xs = [int(p[0]) for p in polygon]
    zs = [int(p[2]) for p in polygon]
    return min(xs), max(xs), min(zs), max(zs)


def _is_rectangle(polygon):
    if len(polygon) != 4:
        return False
    xs = sorted({int(p[0]) for p in polygon})
    zs = sorted({int(p[2]) for p in polygon})
    return len(xs) == 2 and len(zs) == 2


def _subtract_hole(x0, x1, z0, z1, hole):
    """Splits a rectangle around a rectangular hole, returning up to four
    rectangles. Used for the keep plinth ring, which is a walkway around the
    keep rather than a slab under it."""
    hx0, hx1, hz0, hz1 = _polygon_bounds(hole)
    parts = []
    if hz0 > z0:
        parts.append((x0, x1, z0, hz0 - 1))
    if hz1 < z1:
        parts.append((x0, x1, hz1 + 1, z1))
    if hx0 > x0:
        parts.append((x0, hx0 - 1, max(z0, hz0), min(z1, hz1)))
    if hx1 < x1:
        parts.append((hx1 + 1, x1, max(z0, hz0), min(z1, hz1)))
    return [p for p in parts if p[0] <= p[1] and p[2] <= p[3]]


def _rotate_footprint(x, z, size_x, size_z, degrees):
    """Rotates a local cell within a footprint. Prefabs declare rotation_y, and
    ignoring it would silently mirror a tower's entrance onto the wrong face."""
    degrees %= 360
    if degrees == 0:
        return x, z
    if degrees == 90:
        return size_z - 1 - z, x
    if degrees == 180:
        return size_x - 1 - x, size_z - 1 - z
    return z, size_x - 1 - x  # 270


class CitadelAdapter:
    def __init__(self, data, prefab_lookup):
        self.data = data
        self.prefabs = prefab_lookup
        self.problems = []
        self.blocks = []
        self.nav_regions = []
        self.links = []
        self.sockets = []
        self.gate_defaults = {}
        self.gates = []
        self._visual_index = {}
        self._socket_index = None
        self._pending_socket_links = []

    # -- visuals -------------------------------------------------------------

    def _add_block(self, block_id, origin, size, material, nav="SOLID"):
        region = _rect_from_origin_size(origin, size)
        self._visual_index[str(block_id)] = region
        self.blocks.append({
            "id": block_id, "region": region,
            "material": str(material), "nav": nav,
        })

    def _collect_visual_blocks(self, container, key="visual_blocks"):
        for block in (container or {}).get(key, []) or []:
            self._add_block(block.get("id", "block"), block["origin"], block["size"],
                            block.get("material", "exterior_wall"))

    def build_visuals(self):
        self._collect_visual_blocks(self.data.get("foundations"))
        self._collect_visual_blocks(self.data.get("central_keep"))
        self._collect_visual_blocks(self.data.get("gatehouse"))
        self._collect_visual_blocks(self.data.get("courtyards"), "visual_floor_blocks")
        self._collect_visual_blocks(self.data.get("courtyards"), "readability_features")
        self._collect_visual_blocks(self.data.get("ramps"))
        self._collect_visual_blocks(self.data.get("stairs"))
        for deck in (self.data.get("wall_walks") or {}).get("authored_visual_decks", []) or []:
            self._add_block(deck["id"], deck["origin"], deck["size"], deck.get("material", "exterior_trim"))
        self._build_wall_segments()
        self._build_instances()
        self._carve_openings()

    def _build_wall_segments(self):
        """Wall bodies, decks and crenellation from the repeated-segment defaults.
        The spec asks for these to be generated rather than authored per wall."""
        section = self.data.get("repeated_wall_segments") or {}
        defaults = section.get("defaults", {})
        base_y = int(defaults.get("base_y", 2))
        height = int(defaults.get("height", 18))
        thickness = int(defaults.get("thickness", 6))
        for segment in section.get("segments", []) or []:
            origin = segment["origin"]
            length = int(segment["length"])
            material = segment.get("material", "exterior_wall")
            if segment.get("orientation") == "east_west":
                size = [length, height, thickness]
            else:
                size = [thickness, height, length]
            self._add_block(segment["id"], [origin[0], base_y, origin[2]], size, material)

    def _build_instances(self):
        """Prefab instances, including one authored in an earlier schema."""
        contracts = {}
        for contract in (self.data.get("substructures") or {}).get("prefab_contracts", []) or []:
            contracts[str(contract.get("prefab"))] = contract
        for instance in self.data.get("instances", []) or []:
            prefab_id = str(instance.get("prefab"))
            origin = instance.get("origin", [0, 0, 0])
            rotation = int(instance.get("rotation_y", 0))
            contract = contracts.get(prefab_id, {})
            inline = contract.get("visual_blocks")
            if inline:
                size = contract.get("size", [18, 18, 18])
                for block in inline:
                    self._add_rotated_block(instance["id"], block, origin, rotation, size)
                continue
            external = self.prefabs.get(prefab_id)
            if external is None:
                self.problems.append(
                    "instance %s references prefab %s, which has no inline visual_blocks "
                    "and no external definition" % (instance.get("id"), prefab_id))
                continue
            self._add_external_prefab(instance, external, origin, rotation)
        self._connect_instances(contracts)

    def _connect_instances(self, contracts):
        """Turns each instance's `connect_to` list into real traversal links.

        The spec declares which citadel sockets an instance joins, but nothing
        consumed that, so every instanced tower was geometry the player could
        walk around and never enter. Sockets are matched BY TYPE -- a
        courtyard path socket joins the prefab's `path` socket, a wall_walk
        socket joins one of its wall_walk sockets -- which is the pairing the
        spec's own connection_types table describes.
        """
        socket_types = {}
        for socket in (self.data.get("procedural_sockets") or {}).get("sockets", []) or []:
            socket_types[str(socket.get("id"))] = str(socket.get("type", "path"))
        for instance in self.data.get("instances", []) or []:
            instance_id = str(instance.get("id"))
            origin = instance.get("origin", [0, 0, 0])
            contract = contracts.get(str(instance.get("prefab")), {})
            prefab_sockets = contract.get("expected_sockets", contract.get("sockets", [])) or []
            used = set()
            for target_id in instance.get("connect_to", []) or []:
                target_type = socket_types.get(str(target_id))
                target_position = self._all_sockets().get(str(target_id))
                if target_position is None:
                    self.problems.append("instance %s connects to unknown socket %s"
                                         % (instance_id, target_id))
                    continue
                match = None
                for socket in prefab_sockets:
                    if str(socket.get("id")) in used:
                        continue
                    if _types_compatible(str(socket.get("type", "path")), target_type):
                        match = socket
                        break
                if match is None:
                    self.problems.append(
                        "instance %s connects to %s (type %s), but its prefab exposes no "
                        "unused socket of a compatible type" % (instance_id, target_id, target_type))
                    continue
                used.add(str(match.get("id")))
                local = match.get("local_position", [0, 0, 0])
                prefab_point = [origin[0] + int(local[0]), origin[1] + int(local[1]), origin[2] + int(local[2])]
                self._pending_socket_links.append({
                    "id": "%s_to_%s" % (instance_id, target_id),
                    "a": target_position, "b": prefab_point,
                    "classes": ["infantry", "archer", "climber"],
                })

    def _add_rotated_block(self, instance_id, block, origin, rotation, prefab_size):
        local = _rect_from_origin_size(block["origin"], block["size"])
        size_x, size_z = int(prefab_size[0]), int(prefab_size[2])
        xs, zs = [], []
        for lx in (local["x"][0], local["x"][1]):
            for lz in (local["z"][0], local["z"][1]):
                rx, rz = _rotate_footprint(lx, lz, size_x, size_z, rotation)
                xs.append(rx)
                zs.append(rz)
        region = {
            "x": [origin[0] + min(xs), origin[0] + max(xs)],
            "y": [origin[1] + local["y"][0], origin[1] + local["y"][1]],
            "z": [origin[2] + min(zs), origin[2] + max(zs)],
        }
        block_id = "%s_%s" % (instance_id, block.get("id", "block"))
        self._visual_index[block_id] = region
        self.blocks.append({
            "id": block_id, "region": region,
            "material": str(block.get("material", "tower_wall")), "nav": "SOLID",
        })

    def _add_external_prefab(self, instance, prefab, origin, rotation):
        """Stamps a structure authored in another schema into this one.

        Its nav regions and links come along, offset into citadel space, so the
        observation tower stays fully traversable inside the castle rather than
        becoming decorative geometry."""
        instance_id = str(instance.get("id"))
        if rotation % 360 != 0:
            self.problems.append(
                "instance %s asks for rotation_y=%s on external prefab %s; only the "
                "footprint is rotated, its authored nav and links are not, so it is "
                "placed unrotated" % (instance_id, rotation, instance.get("prefab")))
        for block in prefab.get("blocks", []) or []:
            region = _normalise_region(block.get("region", {}))
            self.blocks.append({
                "id": "%s_%s" % (instance_id, block.get("id", "block")),
                "region": _offset_region(region, origin),
                "material": str(block.get("material", "TOWER_STONE")),
                "nav": str(block.get("nav", block.get("navigation", "SOLID"))),
            })
        for region in prefab.get("nav_regions", []) or []:
            entry = dict(region)
            entry["id"] = "%s_%s" % (instance_id, region.get("id", "region"))
            entry["region"] = _offset_region(_normalise_region(region.get("region", {})), origin)
            self.nav_regions.append(entry)
        for link in prefab.get("links", prefab.get("traversal_links", [])) or []:
            entry = dict(link)
            entry["id"] = "%s_%s" % (instance_id, link.get("id", "link"))
            entry["from"] = [link["from"][0] + origin[0], link["from"][1] + origin[1], link["from"][2] + origin[2]]
            entry["to"] = [link["to"][0] + origin[0], link["to"][1] + origin[1], link["to"][2] + origin[2]]
            self.links.append(entry)
        for gate in prefab.get("gates", []) or []:
            entry = dict(gate)
            entry["state_key"] = "%s_%s" % (instance_id, gate.get("state_key", "gate"))
            entry["block_region"] = _offset_region(_normalise_region(gate.get("block_region", {})), origin)
            entry["passage_region"] = _offset_region(_normalise_region(gate.get("passage_region", {})), origin)
            self.gates.append(entry)
            self.gate_defaults[entry["state_key"]] = str(gate.get("default_state", "closed")) == "open"

    def _carve_openings(self):
        """Clear volumes -- gate tunnels and open gate clearances -- are carved
        AFTER the masses they pass through, so a tunnel is a hole rather than a
        block sitting inside a wall."""
        gatehouse = self.data.get("gatehouse") or {}
        opening = gatehouse.get("passable_opening")
        if opening and opening.get("clear_volume"):
            self._add_block(opening["id"], opening["origin"], opening["size"], "EMPTY", nav="SOLID")
        for gate in (self.data.get("gates") or {}).get("visual_and_state_data_only", []) or []:
            clearance = gate.get("open_clearance")
            if clearance:
                self._add_block("%s_clearance" % gate["id"], clearance["origin"], clearance["size"],
                                "EMPTY", nav="SOLID")
            for index, leaf in enumerate(gate.get("closed_visual_blocks", []) or []):
                leaf_id = "%s_leaf_%d" % (gate["id"], index)
                self._add_block(leaf_id, leaf["origin"], leaf["size"], leaf.get("material", "gate"))
                region = _rect_from_origin_size(leaf["origin"], leaf["size"])
                self.gates.append({
                    "state_key": "%s_open" % gate["id"],
                    "block_region": region,
                    "passage_region": region,
                })
            self.gate_defaults.setdefault("%s_open" % gate["id"], False)

    # -- navigation ----------------------------------------------------------

    def build_navigation(self):
        section = self.data.get("nav_regions") or {}
        for region in section.get("regions", []) or []:
            self._add_nav_region(region)
        for stub in self.data.get("nav_region_stubs", []) or []:
            self._add_nav_region(stub)
        self._build_links()

    def _add_nav_region(self, region):
        region_id = str(region.get("id", "region"))
        classes = region.get("agent_classes", [])
        if "volume" in region:
            # Flying ignores ground navigation entirely in the engine, so a
            # 96x42x96 volume would be 387k nav cells that nothing consults.
            self.problems.append(
                "nav region %s is a volume for %s; flying already ignores ground "
                "navigation, so it is not expanded into cells" % (region_id, classes))
            return
        if "segments" in region:
            plane_y = int(region.get("plane_y", 0))
            for segment in region["segments"]:
                deck_id = segment[0] if isinstance(segment, list) else segment
                deck = self._visual_index.get(str(deck_id))
                if deck is None:
                    self.problems.append("nav region %s references unknown deck %s" % (region_id, deck_id))
                    continue
                self.nav_regions.append({
                    "id": region_id, "type": "FLOOR", "allowed": classes,
                    "region": {"x": deck["x"], "y": plane_y, "z": deck["z"]},
                })
            return
        if "generated_from_visual_ids" in region:
            levels = [int(v) for v in region.get("plane_y_levels", [])]
            matched = set()
            for visual_id in region["generated_from_visual_ids"]:
                block = self._visual_index.get(str(visual_id))
                if block is None:
                    self.problems.append("nav region %s references unknown visual %s" % (region_id, visual_id))
                    continue
                top = block["y"][1] + 1
                if top in levels:
                    matched.add(top)
                    self.nav_regions.append({
                        "id": region_id, "type": "FLOOR", "allowed": classes,
                        "region": {"x": block["x"], "y": top, "z": block["z"]},
                    })
            for level in levels:
                if level not in matched:
                    self.problems.append(
                        "nav region %s lists plane_y level %d, but no block in "
                        "generated_from_visual_ids has its top surface there" % (region_id, level))
            return
        polygon = region.get("polygon")
        if not polygon:
            self.problems.append("nav region %s has no polygon, segments or volume" % region_id)
            return
        if not _is_rectangle(polygon):
            self.problems.append(
                "nav region %s is not an axis-aligned rectangle; it is expanded to its "
                "bounding box, which may hand units floor that was never authored" % region_id)
        plane_y = int(region.get("plane_y", polygon[0][1]))
        x0, x1, z0, z1 = _polygon_bounds(polygon)
        rects = [(x0, x1, z0, z1)]
        for hole in region.get("holes", []) or []:
            expanded = []
            for rect in rects:
                expanded.extend(_subtract_hole(rect[0], rect[1], rect[2], rect[3], hole))
            rects = expanded
        for rect in rects:
            self.nav_regions.append({
                "id": region_id, "type": "FLOOR", "allowed": classes,
                "region": {"x": [rect[0], rect[1]], "y": plane_y, "z": [rect[2], rect[3]]},
            })

    def _region_cells(self, region_id):
        cells = []
        for region in self.nav_regions:
            if str(region.get("id")) != region_id:
                continue
            r = _normalise_region(region["region"])
            for x in range(r["x"][0], r["x"][1] + 1):
                for y in range(r["y"][0], r["y"][1] + 1):
                    for z in range(r["z"][0], r["z"][1] + 1):
                        cells.append((x, y, z))
        return cells

    def _all_sockets(self):
        """Every socket the spec declares, wherever it declares it."""
        if self._socket_index is not None:
            return self._socket_index
        index = {}
        for socket in (self.data.get("procedural_sockets") or {}).get("sockets", []) or []:
            index[str(socket.get("id"))] = socket.get("position", [0, 0, 0])
        for container_key in ("central_keep", "gatehouse"):
            for socket in (self.data.get(container_key) or {}).get("sockets", []) or []:
                index[str(socket.get("id"))] = socket.get("position", [0, 0, 0])
        self._socket_index = index
        return index

    def _nearest_cell(self, cells, point):
        best = None
        best_distance = None
        for cell in cells:
            distance = ((cell[0] - point[0]) ** 2 + (cell[1] - point[1]) ** 2
                        + (cell[2] - point[2]) ** 2)
            if best_distance is None or distance < best_distance:
                best_distance = distance
                best = cell
        return best

    def _link_endpoints(self, link, from_cells, to_cells):
        """Where a region-to-region link actually touches down.

        The spec says WHICH regions a link joins but not where, and it offers
        two better answers than guessing:

          * `visual_id` names the ramp or stair block, so both ends are anchored
            to the geometry the player can see.
          * `socket_pair` names two sockets, which are exact positions.

        Closest-pair is the fallback only. Using it everywhere was wrong in a
        way the probe made obvious: all four keep ramps and all three keep
        bridges collapsed onto one identical pair of cells, because the regions
        they join touch at a corner. Four ramps that all arrive at the same
        corner is not a castle."""
        visual_id = link.get("visual_id")
        if visual_id:
            block = self._visual_index.get(str(visual_id))
            if block is not None:
                centre = ((block["x"][0] + block["x"][1]) // 2,
                          (block["y"][0] + block["y"][1]) // 2,
                          (block["z"][0] + block["z"][1]) // 2)
                return self._nearest_cell(from_cells, centre), self._nearest_cell(to_cells, centre)
            self.problems.append("link %s names visual_id %s, which does not exist"
                                 % (link.get("id"), visual_id))
        pair = link.get("socket_pair")
        if pair and len(pair) == 2:
            sockets = self._all_sockets()
            a = sockets.get(str(pair[0]))
            b = sockets.get(str(pair[1]))
            if a is not None and b is not None:
                return self._nearest_cell(from_cells, a), self._nearest_cell(to_cells, b)
            missing = [str(name) for name in pair if sockets.get(str(name)) is None]
            self.problems.append("link %s names sockets %s, which are not declared anywhere"
                                 % (link.get("id"), missing))
        return _closest_pair(from_cells, to_cells)

    def _build_links(self):
        """Region-to-region links become cell-to-cell links, anchored to the
        link's own `visual_id` or `socket_pair` where it gives one."""
        for link in (self.data.get("traversal_links") or {}).get("links", []) or []:
            link_id = str(link.get("id", "link"))
            link_type = str(link.get("type", "")).upper()
            if link_type == "FREE_VOLUME":
                continue
            from_cells = self._region_cells(str(link.get("from")))
            to_cells = self._region_cells(str(link.get("to")))
            if not from_cells or not to_cells:
                self.problems.append(
                    "link %s joins %s -> %s, and at least one of those regions has no cells"
                    % (link_id, link.get("from"), link.get("to")))
                continue
            pair = self._link_endpoints(link, from_cells, to_cells)
            mapped = {"gate_passage": "GATE_LINK", "ramp": "RAMP", "stair": "STAIR",
                      "bridge": "FLOOR_LINK"}.get(str(link.get("type")), "RAMP")
            self.links.append({
                "id": link_id, "type": mapped,
                "from": list(pair[0]), "to": list(pair[1]),
                "allowed": link.get("agent_classes", []),
                "width": int(link.get("width_blocks", 4)),
            })

    def resolve_socket_links(self):
        """Socket-to-socket links, snapped to the nearest standable cell at each
        end. Run after nav regions exist, because a link to a socket floating in
        the air is no use -- it has to land where a unit can stand."""
        all_cells = []
        for region in self.nav_regions:
            r = _normalise_region(region["region"])
            for x in range(r["x"][0], r["x"][1] + 1):
                for y in range(r["y"][0], r["y"][1] + 1):
                    for z in range(r["z"][0], r["z"][1] + 1):
                        all_cells.append((x, y, z))
        for pending in self._pending_socket_links:
            a = self._nearest_cell(all_cells, pending["a"])
            b = self._nearest_cell(all_cells, pending["b"])
            if a is None or b is None or a == b:
                continue
            self.links.append({
                "id": pending["id"], "type": "FLOOR_LINK",
                "from": list(a), "to": list(b),
                "allowed": pending["classes"], "width": 2,
            })

    # -- output --------------------------------------------------------------

    def to_structure(self):
        size = (self.data.get("dimensions") or {}).get("size", [96, 46, 96])
        return {
            "id": str(self.data.get("id", "composition_structure")),
            "display_name": str(self.data.get("name", self.data.get("id", "Structure"))),
            "dimensions": [int(size[0]), int(size[1]), int(size[2])],
            "blocks": self.blocks,
            "nav_regions": self.nav_regions,
            "links": self.links,
            "sockets": self._sockets(),
            "gates": self.gates,
            "gate_defaults": self.gate_defaults,
        }

    def _sockets(self):
        out = []
        for socket in (self.data.get("procedural_sockets") or {}).get("sockets", []) or []:
            position = socket.get("position", [0, 0, 0])
            out.append({
                "id": socket.get("id", "socket"),
                "type": str(socket.get("type", "path")).upper(),
                "position": [int(position[0]), int(position[1]), int(position[2])],
                "facing": str(socket.get("direction", "north")),
                "width": 1,
            })
        return out

    def materials(self):
        palette = (self.data.get("materials") or {}).get("palette", {})
        out = {}
        for role, _name in palette.items():
            out[str(role)] = {"collision": ROLE_COLLISION.get(str(role), "solid")}
        out["EMPTY"] = {"collision": "none"}
        return out


def _normalise_region(region):
    """Accepts either an inclusive {x:[a,b]} region or a bare int per axis."""
    def axis(value):
        if isinstance(value, list):
            return [int(value[0]), int(value[1])]
        return [int(value), int(value)]
    return {"x": axis(region.get("x", 0)), "y": axis(region.get("y", 0)), "z": axis(region.get("z", 0))}


def _offset_region(region, origin):
    return {
        "x": [region["x"][0] + origin[0], region["x"][1] + origin[0]],
        "y": [region["y"][0] + origin[1], region["y"][1] + origin[1]],
        "z": [region["z"][0] + origin[2], region["z"][1] + origin[2]],
    }


def _types_compatible(prefab_type, target_type):
    """The spec's connection_types table, reduced to what pairing actually
    needs: paths and roads join paths, wall walks join wall walks and vertical
    routes."""
    ground = {"path", "road", "courtyard_path", "ramp", "gate"}
    high = {"wall_walk", "bridge", "vertical_route", "roof_path"}
    if prefab_type in ground and target_type in ground:
        return True
    return prefab_type in high and target_type in high


def _closest_pair(from_cells, to_cells):
    best = None
    best_distance = None
    # Sampled rather than exhaustive: these regions run to thousands of cells
    # and an all-pairs search over the citadel's links is minutes of build time
    # for an answer that does not change.
    step_a = max(1, len(from_cells) // 400)
    step_b = max(1, len(to_cells) // 400)
    for a in from_cells[::step_a]:
        for b in to_cells[::step_b]:
            distance = (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2
            if best_distance is None or distance < best_distance:
                best_distance = distance
                best = (a, b)
    return best


def load_composition(path, prefab_lookup):
    with open(path, "r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    adapter = CitadelAdapter(data, prefab_lookup)
    adapter.build_visuals()
    adapter.build_navigation()
    adapter.resolve_socket_links()
    return adapter
