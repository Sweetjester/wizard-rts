# Block Structure Test Pack

This pack is designed to be handed directly to Claude/Codex as a deterministic construction spec for a Godot block-based RTS.

## Files
- `structures.yaml` — canonical data for blocks, traversal, gates, stairs, ramps, portals, climb points and procedural sockets.
- `CLAUDE_PROMPT.txt` — paste this into Claude with the YAML file.

## Core implementation rule
Do NOT infer navigation from visible geometry.

Each structure must build three independent layers:
1. VISUAL — block meshes, decorations, lights.
2. COLLISION — solid/conditional collision.
3. NAVIGATION — walkable regions and authored traversal links.

## Coordinate convention
- X = east/west
- Y = vertical
- Z = north/south
- Structure origin = minimum local X/Y/Z
- All YAML ranges are inclusive
- 1 block = 1 world unit by default

## Suggested first test
Use `fortress_gatehouse_01`.

Expected behavior:
- Infantry, archer and climber can use the gate and wall stairs.
- Heavy units can pass the open gate but cannot reach the wall-walk.
- Climbers can use authored climb points on structures that expose them.
- Closed gates remove their nav connection.
- Flying units ignore all ground navigation.
