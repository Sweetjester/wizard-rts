# Block structures (experimental)

Branch: `experimental/block-structures`. Nothing here is wired into the shipping
game yet — it is a self-contained system with its own tests.

The goal is Minecraft-style authored blocks used to generate large explorable
structures (caves, ruins, gatehouses, ziggurats) that units can enter and move
through vertically.

## Layout

| File | Role |
|---|---|
| `data/block_structures/structures.yaml` | **Source of truth.** Authored spec. Edit this. |
| `tools/blocks/convert_structures.py` | YAML → JSON build step, plus validation. Re-run after editing the YAML. |
| `resources/block_structures/structures.json` | Build artefact. Do not hand-edit. |
| `structure_library.gd` | Loads the JSON, caches definitions. |
| `structure_definition.gd` | Expands authored regions into solid cells, nav cells and links. |
| `structure_navigation.gd` | Per-unit-class traversal. The part that has to be right. |
| `scripts/core/block_structure_smoke_test.gd` | Proves the pack's cases A–G. |
| `scripts/tools/block_structure_probe.gd` | Diagnostic dump of every structure. |
| `structure_builder.gd` | Block meshes (one MultiMesh) and per-cell collision. |
| `structure_debug_draw.gd` | Nav / link / socket / gate debug layers. |
| `scenes/blocks/block_structure_test.tscn` | The runnable viewer. |

Godot has no YAML parser, and every other YAML in this repo (`props/specs`,
`units/specs`) is consumed by Python tooling and never by the game — so the
build step is the established pattern, not a new dependency.

```bash
python tools/blocks/convert_structures.py
```

## The rule this system exists to enforce

**Navigation is never inferred from rendered geometry.** Three independent
layers, authored separately:

- **solid cells** — collision, what a block physically occupies
- **nav cells** — where a unit may stand, with the classes each region permits
- **links** — the *only* way to change elevation: stairs, ramps, ladders, climb
  points, portals, one-way drops

There is deliberately no implicit step-up. An implicit rule would be exactly the
geometry-derived navigation the spec forbids.

Later blocks override earlier ones, which is how a `VOID_DECOR` volume carves a
gate passage through a solid wall. See "One rule worth knowing" below for how
block `nav:` fields relate to walkable ground — they do not create it.

## Schema problems found in the pack (reported, not repaired)

The converter validates and reports; it never silently fixes. Four problems come
straight from the data:

- `hollowspire_tower_01` — block at `y=13`, declared height 13 (valid 0–12)
- `giant_stone_bridge_01` — block at `y=5`, declared height 5 (valid 0–4)
- `sunken_temple_01` — negative `y` (−2) contradicts the spec's own origin rule
  ("local origin is the minimum corner"), twice

And one larger one, found by probing rather than validation:

**Every vertical link's bottom endpoint sits in a cell no nav region declares.**
In `fortress_gatehouse_01`, `left_stair` starts at `(3,0,8)` — inside the solid
block `x[3,8] y[0,3] z[5,9]`. Both climb points on `titan_skull_keep_01` have the
same problem. The gatehouse also has no ground-level nav region at all, and its
gate passage dead-ends into solid stone rather than running through.

Consequence: the pack's own test cases **B** (infantry climbs to the wall-walk)
and **E** (climber uses a climb point) cannot pass against the original data.

Rather than invent a rule like "link endpoints are implicitly walkable" — which
is the inferred navigation the spec forbids — the fix is authored where
authoring belongs. `fortress_gatehouse_02_walkable` is a separate structure id
with the passage carved through and a ground floor declared. **The original is
left byte-for-byte intact**, and the smoke test asserts its gaps still exist, so
if the source data is ever repaired the test says so instead of diverging
quietly.

## Viewer

```bash
Godot --path . scenes/blocks/block_structure_test.tscn
```

| Key | Does |
|---|---|
| `Tab` / `Shift+Tab` | cycle structure (all 11) |
| `C` | cycle unit class -- infantry, archer, climber, heavy, siege, flying |
| `G` | toggle every gate |
| `1` `2` `3` `4` | toggle nav cells / links / sockets / solid blocks |
| drag, wheel | orbit and zoom |

Nav cells are coloured by **reachability for the selected class**, measured from
a real entry point rather than from "anywhere it could stand":

- **green** reachable
- **yellow** standable but cut off -- the interesting state, and the one a
  two-colour view would hide
- **grey** not standable at all
- gates are **blue** open, **red** shut

Switching infantry to heavy on the gatehouse shows the whole mechanic in one
keypress: the wall-walk goes from green to grey and the stair link greys out,
because heavy is `can_use_stairs: false`. Key `4` hides the stone so the links
buried inside it become visible.

`scripts/tools/block_structure_screenshot.gd` captures a set of these without
driving the scene by hand.

## One rule worth knowing

**Blocks carve collision; `nav_regions` declare where units may stand.** A
block's own `nav:` field is kept (as `open_cells`, for headroom and clearance)
but never creates walkable ground.

This was not the first implementation, and the debug view is what caught it. A
gatehouse's carved passage is four blocks tall, so treating a `nav: FLOOR` block
volume as floor produced four stacked levels of walkable ground -- three of them
hanging in mid-air. Inferring support instead ("floor where the cell below is
solid") would be deriving navigation from block layout, which is the one thing
the spec forbids. The pack's own rule 4 settles it: nav_regions define
occupiable cells.

## The elevation system

`block_nav_world.gd` is the point of all of this. One navigation lattice for a
whole map, where a node is `(cell.x, level, cell.z)`.

The insight it rests on: **the terrain is already a block grid.** Every cell
stores an integer height, which is a column of blocks with one standable surface
on top. This adds nothing to terrain — it just stops assuming a column can only
have *one* surface. A wall-walk over a gate passage is the same column with two
standable levels, and once that is expressible, interiors, bridges over roads
and sunken temples all fall out of the same representation.

| Piece | Role |
|---|---|
| `block_unit_rules.gd` | Class capabilities, shared by the lattice and per-structure nav so they cannot drift apart. |
| `block_nav_world.gd` | The lattice: terrain nodes, placed structures, A* with elevation. |
| `demo_block_terrain.gd` | A small block landscape — plateaus, ramps, cliffs, a pond. |
| `block_world_demo.gd` | The walkable demo: structures on terrain, agents pathing through them. |

```bash
Godot --path . res://scenes/blocks/block_world_demo.tscn
```

`Space` re-rolls destinations, `P` toggles paths, `N` toggles nav cells, `C`
cycles which class the overlay is for, `R` rebuilds.

Two rules hold everywhere:

- **Elevation only changes through an authored link.** No implicit step-up
  anywhere in the file. On terrain that "link" is the existing ramp rule, which
  is *delegated to MapGenerator* rather than reimplemented — `is_cliff_edge_cell()`
  already is that rule, and a second opinion about whether a unit can walk up a
  cliff is how movement and vision end up disagreeing.
- **A structure's base level comes from the terrain under it**, so the two
  elevation sources compose. An earlier demo pinned every structure to level 0
  and left them half-buried where the ground rose.

Nodes are encoded as a single int rather than a `Vector3i` key, and the A* heap
uses `PackedFloat64Array`. Both are deliberate from the start: a 96×96 map is
~9000 terrain nodes before any structure, and float32 heap costs are what made
the flow field silently reach 3384 cells instead of 7017.

## Wiring the real game to it

`block_nav_bridge.gd` is where the lattice and the live game meet, and the only
place they do. The lattice speaks in nodes `(x, level, z)`; `RTSUnit` speaks in
world positions. Keeping the translation in one node means `BlockNavWorld` never
depends on the game's units and `RTSUnit` never depends on the lattice — delete
the bridge and both sides still work, they just stop talking.

On `RTSUnit`:

- `nav_level` — the level the unit is standing on. `0` for anything that has
  never been given a lattice path, and level 0 *is* the terrain surface, so
  ordinary 2D movement is untouched.
- `path_levels` — runs parallel to `path`, empty for every ordinary order.
- `follow_block_path(points, levels)` — hands a unit a lattice route.

Every removal from `path` goes through one `_pop_path_front()` helper, because
two call sites pop (arrival and the lookahead shortcut) and a desync between
them would put a unit in the right place on the wrong floor.

`Map3DView` renders a unit at `nav_level` when it has one. Without that the
elevation would exist in the simulation and be invisible on screen — a unit on a
wall-walk would draw inside the passage below it.

Proven in `unit_block_elevation_smoke_test.gd` against the **real procedural
map**: a live `RTSUnit` is ordered onto a wall-walk six levels above where it
started, runs its own movement tick until the route is done, and finishes with
`nav_level == 6`. A heavy given the identical order is refused. And a plain move
order is asserted to carry no elevation data at all, so the lattice cannot
quietly start affecting units nobody put on it.

## In the live game

`BlockNavBridge` is a node in `main_map.tscn`. On startup it waits for map
generation to settle, builds the lattice from the real `MapGenerator`, and drops
its `auto_place` structures onto flat sites near the player's base.

Placement is anchored to the **wizard tower**, not the map origin or centre.
Scanning from (2,2) put structures in the far corner; scanning from the centre
put them 50 cells away in permanent fog. Either way nothing ever walked past
them, which for a landmark system is the one outcome that makes it pointless.
A 16-cell minimum keeps them outside the player's build radius.

Placing a structure also registers its **ground-level walls as 2D dynamic
blockers**. The 2D pathfinder knows nothing about levels, so without that,
ordinary units walk straight through a building that is solid in the lattice.
Only ground level is registered — a wall-walk six levels up must not block
anything on the floor — and cells the structure declares standable (the gate
passage) are skipped, or the gate would be sealed shut.

Right-click routing lives in `SelectionController._try_block_move_order()`. It
fires **only when the destination column has more than one standable level**.
Ordinary ground has exactly one, so it returns false there and the existing 2D
pathfinder handles the order with its formation offsets, shared paths and flow
fields completely untouched. On a multi-level column it sends each unit to the
highest level it can both stand on and reach.

That last rule is demo-grade and worth knowing: you cannot currently click the
ground *underneath* a wall-walk. A proper level-picking gesture — a modifier, or
picking from the camera ray — is the fix.

`Map3DView` draws the placed structures and raises the fog plane above the
tallest one. Fog is a horizontal plane at height 6; the gatehouse is 9 tall, so
without that it poked through and stood lit in unexplored blackness.

Verified in `block_structures_in_game_smoke_test.gd` on the real generated map:
structures placed, walls blocking 2D, and infantry right-clicked **6 levels up**
onto a wall-walk. The test scans for a climbable column rather than taking the
first multi-level one, because not every raised surface is reachable on foot — a
tower roof served only by a climb point is climber-only, and an infantry order
there correctly falls back to the ground floor.

## Not built yet

- Test agents that actually walk a path, rather than reachability colouring
  (the traversal graph is there; nothing animates along it yet)
- Procedural placement into map generation
- Destruction, and any tie-in to the `StructureComponents` work on the other
  branch — the two systems overlap and have not been reconciled
- **Placement is startup-time, not procedural.** The bridge drops structures
  onto flat sites; `MapGenerator` itself knows nothing about them, so they do not
  participate in road routing, plot layout or landmark selection.
- **Attack-move, patrol and shared-path group orders** do not route through the
  lattice — only plain move orders do.
- **2D presentation shows nothing.** Placed structures render in the 3D view
  only; in 2D their walls block movement but are invisible.
- Flow fields over the lattice, for wave movement at hundreds of units. A* per
  unit is fine for the demo's 18 and is not fine for 300.
- Combat, vision and fog are all still flat: `has_line_of_sight` takes a terrain
  height, not a block level, so a unit on a wall-walk sees as though it were on
  the ground beneath it.
- Destruction: reconciling this with `StructureComponents` on the other branch.
