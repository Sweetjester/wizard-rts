# Overnight Worker Instructions

This is an operating brief for an authorized task, not permission to modify any
repository, spend money, install tools or schedule recurring jobs. The owner
must provide a completed asset brief and explicit access/budget boundaries.

## Copyable Task Prompt

You are implementing ONE approved Kon asset in an existing Godot RTS project.
Read tools/asset_production/README.md, STYLE_AND_QUALITY.md, the relevant UNITS.md
or BUILDINGS.md, and the completed asset brief supplied with this task. Inspect
the nearest working example and current code before editing. Your target is a
working, evidence-backed REVIEW_READY asset, not merely concept art or a plan.

Preserve unrelated changes. Work only in the authorized checkout and scope.
Do not reset the repository, overwrite another worker's files, delete source
art, change protected baseline assets or install dependencies without permission.
Do not invent API keys, tool access, missing reference images or approval.

Follow the stages below. Write a durable progress checkpoint after each stage
and before stopping. Cite source files and concrete artifacts. Use the existing
engine/toolchain; do not introduce a competing framework. Keep simulation and
presentation separate. Match the supplied reference and approved gameplay view.

Never claim a test passed without the fresh log and expected success marker.
Never change an expected result merely to conceal failure. Never present a
concept rendering as the actual game model. Report source-pose and baked-frame
counts separately. Clearly state mirrored views, missing directions and limits.

Do not commit, merge, push, purchase generation credits, start ongoing automation
or run a paid service unless the owner explicitly authorized that action.
When done, leave the implementation and evidence, plus a short handoff showing
how to try it. Reserve APPROVED for the owner.

## Stage Loop

1. PREFLIGHT: inspect branch/status, existing instructions, references, available
   Godot/Python/image tools and required permissions. Read current integrations.
   Run relevant baseline checks where feasible. Record pre-existing warnings.
   If essential art references/tools are missing, do not fake them.
2. CONTRACT: complete exact dimensions/actions, invariant gameplay, paths and
   verification plan. Resolve unsupported assumptions before modifying shared code.
3. SOURCE: generate or prepare production artwork under the authorized budget.
   Inspect alpha, silhouette, reference consistency and source boundaries.
   Keep a valid source version; no unattended endless regeneration loop.
4. VERTICAL SLICE: implement one form/action or one walkable floor through the
   normal runtime path. Capture at gameplay scale. Fix broad mistakes now.
5. COMPLETE: add remaining states/forms or rooms/gates; integrate catalog,
   production/research and existing presentation without unrelated refactors.
6. VERIFY: run focused, shared-regression and real-map checks; inspect logs,
   captures and actual animation. Apply the visual rubric honestly.
7. HANDOFF: mark REVIEW_READY only when required checks and evidence exist.
   Otherwise leave BLOCKED/PARTIAL with precise failures and next actions.

## Retry And Stop Policy

The task's explicit time/spend limits take precedence. If no numerical budget
was authorized, do not assume paid generations are unlimited. Ask before costs.

- A functional failure gets a diagnosis and a focused fix, then a rerun.
- After three attempts at the same failing condition, stop that path and write
  the failing evidence, attempted fixes and smallest needed decision. Continue
  only independent authorized work that does not hide the blocker.
- After two visual revision passes without improvement, preserve the best
  candidate and request review. Do not compensate by changing approved style.
- At the deadline, terminate/poll required test processes cleanly and checkpoint.
  Unfinished is acceptable; falsely completed is not.
- Pause when concurrent edits conflict with your task, a required shared-system
  redesign emerges, permissions are denied or a destructive change is needed.

## Progress Checkpoint Format

Maintain a task-local PROGRESS.md, not this shared handbook:

```text
Asset / date / checkout:
Current stage:
Brief and references:
Changed files:
Completed work:
Last commands and exact outcomes:
Current screenshots / source / atlas versions:
Known errors (new versus baseline):
Attempts used / remaining authorized budget:
Running processes and whether still needed:
Next concrete action:
Blocked decision, if any:
```

## Morning Review Packet

Deliver the completed brief, implementation handoff, fresh logs, source prompt,
actual runtime screenshots and animation review. Show the approved comparison
at matching camera scale. List failures and untested behavior before optional
polish. The owner should be able to assess it without reading a long chat.

## Sensible Rollout

First unattended trial: one art-only variant using the known unit pipeline,
or one compact building with already-understood mechanics. Review the packet
before granting broader scope. Then increase complexity one task at a time.

Use isolated checkouts for concurrent code work. Do not merge multiple workers'
catalog, HUD or generated-library changes blindly. A coordinator or owner should
review and rerun integration checks after combining them.

This document helps a model follow a process; it cannot give a text-only model
visual inspection or image-generation capability it does not possess. Without
those tools, restrict it to code/data preparation and leave visual acceptance
blocked for a capable reviewer. Passing automated tests is not artistic judgment.
