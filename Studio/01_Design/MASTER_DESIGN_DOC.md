# Wizard RTS Master Design Doc

Authoritative design vision for the project — the "why" behind every system, intended as the shared reference for every agent (human or AI) working on Wizard RTS. Where this doc's direction differs from what's currently implemented, treat this doc as the target and `wizard-rts/wizard-rts/PROJECT_BRIEF.md` as the record of current build status; closing that gap is design/engineering work, not a doc conflict.

## 1. One-Sentence Pitch

Wizard RTS is a roguelike real-time strategy game where the player controls a powerful wizard, explores a dangerous procedurally generated fantasy map, chooses where to establish a base, survives escalating enemy pressure, discovers upgrades, and completes a run-specific objective before the wizard or wizard tower is destroyed.

---

## 2. Core Identity

Wizard RTS combines:

- RTS base building and army control
- Roguelike run structure
- Hero/wizard-driven fantasy power progression
- Procedural map exploration
- Survival defense against organized enemy pressure
- Tactical terrain, roads, chokepoints, elevation, and base placement decisions

The game should feel like the player is carving out a fragile magical foothold in a hostile fantasy world, then gradually turning that foothold into a position of strength.

The fantasy is not "generic commander builds town." The fantasy is:

> "I am a wizard establishing a dangerous magical tower in the wilderness, raising strange forces, surviving the night, and pushing deeper into the unknown."

---

## 3. Core Gameplay Loop

Each run follows this broad structure:

```text
Choose class
-> spawn with wizard
-> scout surrounding map
-> identify possible base plots
-> choose where to settle
-> establish wizard tower
-> build economy and defenses
-> survive enemy trickle and assault waves
-> explore outward from the base
-> discover content plots, quests, merchants, bosses, and upgrades
-> research upgrades at the wizard tower
-> adapt army and strategy
-> complete the map objective
-> win the run
```

The run is lost if:

- The wizard dies
- The wizard tower is destroyed

The run is won when:

- The selected map objective is completed

---

## 4. Intended Player Experience

The player should constantly be making interesting tradeoffs:

- Settle early in a safe but poor location, or scout longer for a stronger base plot?
- Defend the base, or risk sending the wizard out to explore?
- Invest in economy, army, tower upgrades, or wizard power?
- Fortify chokepoints, or build a mobile force?
- Push toward objectives, or farm more upgrades first?
- Choose a risky class-specific power spike, or a safer general upgrade?

The game should create tension through limited information, time pressure, and escalating threats, not through excessive micromanagement.

The player should feel clever when they:

- Pick a strong base location
- Use terrain well
- Build around class strengths
- Survive a dangerous night
- Discover a powerful upgrade combination
- Turn the map layout into an advantage

---

## 5. Camera, Perspective, and Scale

Wizard RTS is an RTS first. The player views the game from an elevated tactical camera.

Recommended direction:

- 3D world with stylized illustrated presentation
- Top-down or angled RTS camera
- Clear silhouettes for units, structures, enemies, terrain, and interactable plots
- Readability takes priority over visual noise

Expected scale:

- Large-scale RTS battles
- Hundreds of units on screen, not dozens
- Base should be readable at a glance
- Army control should still stay tactical rather than high-APM competitive RTS — at hundreds of units, that means leaning on strong control tooling (control groups, army-wide orders, smart formations) to keep it manageable, not on the player's twitch reflexes
- Not every unit is equally controllable, by design — see Section 38, Micromanageable Levels. Control tooling raises the ceiling on what the player *can* manage; micromanageable levels lower the amount that *needs* managing

The game should avoid becoming a full city builder. The base exists to support survival, exploration, and objective completion.

---

## 6. Art Direction

Art style:

- Illustrated fantasy
- Strong silhouettes
- Dark, moody, readable shapes
- High-contrast unit identities
- Stylized rather than realistic

Reference touchstones:

- Hollow Knight: clean silhouettes, moody fantasy, strong shape language
- Darkest Dungeon 2: dramatic lighting, expressive forms, harsh illustrated character shapes

Art priorities:

- Units must be readable at RTS camera distance
- Each class should have a distinct visual identity
- Enemy factions should be recognizable by shape and color language
- Terrain elevation must be visually understandable
- Roads must clearly guide player attention
- Content plots should look enticing and mysterious

Avoid:

- Muddy silhouettes
- Overly realistic low-contrast textures
- Visual clutter that makes combat unreadable
- Generic fantasy assets that do not support the wizard identity

**See also**: Section 37 (Artwork Generation Pipeline) for the current state of the tooling that produces this art, and the gap between this direction and what the pipeline can currently deliver.

---

## 7. Audio Direction

Audio should support immersion, threat awareness, and fantasy atmosphere.

Core audio goals:

- Make maps feel alive
- Signal day/night transitions clearly
- Make incoming waves feel threatening
- Give each class a distinct magical identity
- Make exploration feel mysterious and dangerous
- Use weather as both atmosphere and gameplay feedback

Important sounds:

- Wizard spellcasting
- Tower activity
- Resource gathering
- Enemy approach warnings
- Wave horns, drums, chants, or magical omens
- Weather changes
- Objective discoveries
- Boss introductions
- Upgrade research completion

Audio should help the player understand what is happening even while looking elsewhere.

---

## 8. Run Structure

A run is a self-contained session.

Each run includes:

- Class selection
- Procedural map generation
- Randomized or semi-randomized objective
- Randomized upgrade opportunities
- Dynamic enemy pressure
- Exploration-based progression
- Final objective completion or failure

The player does not start with a fully functioning base. The opening should involve vulnerability and decision-making.

Recommended run phases:

**Phase 1: Arrival** — the wizard enters the map with limited support.
Goals: scout nearby area, avoid early danger, locate base plot candidates, learn the local terrain.

**Phase 2: Settlement** — the player chooses a base plot and establishes the wizard tower.
Goals: commit to a base location, begin economy, build first defenses, prepare for first enemy pressure.

**Phase 3: Survival** — enemy attacks become more consistent.
Goals: stabilize economy, produce units, defend against trickle attacks, survive organized waves, make first upgrade choices.

**Phase 4: Expansion** — the player pushes outward from the base.
Goals: explore content plots, clear enemy camps, find merchants/quests/upgrade sources, secure better resources, adapt army composition.

**Phase 5: Objective Push** — the player commits to completing the run objective.
Goals: defeat boss, complete ritual, destroy enemy site, defend finale (or equivalent); use accumulated upgrades and map knowledge; survive final pressure.

---

## 9. Win and Loss Conditions

### Loss Conditions

The run fails immediately if:

- The wizard dies
- The wizard tower is destroyed

**Design note**: the wizard and tower are both anchors of the run. The wizard represents mobility, agency, and exploration. The tower represents settlement, economy, and long-term power.

### Win Conditions

The run is won by completing the selected objective.

Possible objective types:

- Defeat a boss
- Destroy an enemy stronghold
- Complete a magical ritual
- Survive a final siege
- Recover and activate ancient relics
- Seal portals across the map
- Escort or protect a powerful magical entity
- Cleanse corrupted landmarks
- Hold multiple map locations for a duration

A map may support multiple possible objectives, but only one primary win condition should be selected for a run.

---

## 10. Wizard

The wizard is the player's most important unit.

The wizard should:

- Be powerful but vulnerable
- Enable exploration
- Represent the chosen class
- Cast impactful spells
- Be central to upgrade decisions
- Create tension when far from base

The wizard should not:

- Solo the entire map without support
- Become irrelevant after the army grows
- Be so fragile that exploration feels bad

Possible wizard functions:

- Combat caster
- Builder/founder of the tower
- Upgrade researcher
- Scout
- Ritual activator
- Class mechanic anchor

Wizard death ends the run, so the player should always care where the wizard is.

---

## 11. Wizard Tower

The wizard tower is the heart of the base.

The tower should:

- Anchor the player's settlement
- Serve as the main research structure
- Enable roguelike upgrades
- Represent the run's long-term power
- Be the main object enemies want to destroy

The tower may provide: build radius, research access, magical defenses, resource storage, class-specific mechanics, upgrade slots, map vision upgrades, ritual/objective interactions.

Tower destruction ends the run. The tower should feel powerful, but its placement should be a serious commitment.

---

## 12. Base Placement

Choosing where to settle is one of the most important decisions in the game.

Base plots should create tradeoffs between: defensibility, resource quality, road access, distance from objectives, enemy proximity, expansion potential, terrain advantage, access to content plots.

A good base location might have: chokepoints, high ground, nearby resources, good road access, safe expansion space.

A risky base location might have: rich resources, better map position, more nearby threats, multiple attack angles, poor visibility.

The player should rarely have an obviously correct base location.

---

## 13. Economy

The economy should be meaningful but not bloated.

Primary economy goals: force base placement decisions, support army production, support defense building, support upgrades, encourage exploration and expansion.

Possible resource types:

- **Mana**: magical energy, spells, research, tower upgrades
- **Gold**: merchants, units, structures, general economy
- **Wood/Stone**: buildings and defenses
- **Essence**: rare roguelike upgrade currency, bosses, elite camps
- **Food/Supply**: unit cap or population pressure

**Recommendation**: start with a small number of resources. Avoid overcomplicating the economy before the core loop is fun.

The economy should connect to map control. The player should want to leave the base because the best resources, upgrades, merchants, and objectives are outside the starting area.

---

## 14. Building System

Buildings should support the core loop.

Possible building categories: wizard tower, resource gathering structures, unit production structures, defensive structures, research or upgrade structures, class-specific magical structures.

Buildings should not become the whole game. Every structure should support one of: survive, explore, produce, upgrade, complete objective.

Base layouts should interact with terrain, roads, chokepoints, and enemy paths.

---

## 15. Units

Units should be class-driven. Each class should have a unique roster rather than shared generic units.

Recommended class roster structure:

- 1 wizard
- 2-3 core units
- 1 defensive or utility unit
- 1 advanced unit
- 1 elite or class-defining unit
- Optional summoned, temporary, or upgraded variants

Units should be readable by: silhouette, color accents, animation style, role clarity.

Unit roles may include: frontline blocker, ranged damage, siege, scout, healer/support, anti-swarm, anti-armor, summoned disposable unit, trap or terrain-control unit, flying or terrain-ignoring unit.

Every unit also carries a **micromanageable level** — how far it obeys orders at all. See Section 38. Treat it as a defining stat alongside role, not as a behaviour detail to settle during implementation.

The game should avoid unit rosters where every class has identical equivalents.

---

## 16. Classes

Classes are a major source of replayability.

Each class should have: unique wizard identity, unique unit roster, unique economy or resource twist, unique defensive style, unique exploration pattern, unique upgrade pool, clear difficulty rating, strong strengths and weaknesses.

Example class design template:

```text
Class Name:
Fantasy:
Difficulty:
Core mechanic:
Wizard role:
Economy twist:
Defensive style:
Exploration style:
Core units:
Advanced units:
Signature upgrades:
Weaknesses:
```

### Class design examples

**Necromancer** — raises armies from death, converts enemy corpses into value, strong attrition and swarm potential.
Possible mechanics: corpses become a resource; units are cheap but fragile; deaths can fuel spells or summons; weak early economy, strong snowball.
Weaknesses: vulnerable before corpses accumulate; may struggle against enemies that leave no corpses; requires careful battle positioning.

**Geomancer** — shapes terrain and fortifies the map, excels at chokepoints and defensive planning.
Possible mechanics: builds walls, stone wards, and terrain blockers; gains bonuses on high ground; can create or reinforce chokepoints.
Weaknesses: slow expansion; less mobile army; weak if forced to fight in open ground.

**Stormcaller** — mobile, volatile, high-damage magic, uses weather and lightning.
Possible mechanics: strong during storms; fast units and burst spells; can overload structures or enemies.
Weaknesses: fragile; inconsistent power windows; requires active map movement.

**Beast Druid** — commands beasts and living wilderness, strong scouting and map presence.
Possible mechanics: tames neutral creatures; grows living defenses; gains bonuses in forests or wild terrain.
Weaknesses: less effective on barren maps; may rely on map-specific opportunities; lower structure durability.

---

## 17. Roguelike Upgrade System

The roguelike system is expressed through RTS upgrades.

Upgrades may be found on the map, dropped from bosses or elite camps, earned from quests, bought from merchants, discovered in ruins, offered randomly after major milestones, or researched at the wizard tower.

Upgrades should change playstyle, not only increase stats.

Upgrade categories: wizard upgrades, unit upgrades, tower upgrades, economy upgrades, class-specific upgrades, general upgrades, rare run-defining upgrades, tier 2/3 unlocks.

Examples:

- Skeletons explode on death
- Archers gain fire arrows at night
- Tower fires chain lightning during storms
- Workers gather faster on high ground
- Wizard gains a teleport spell
- Golems become slower but gain armor
- Farms generate mana during rain
- Roads provide movement speed and vision
- Killing elites unlocks advanced unit variants

Good upgrades should make the player think: "This changes what I want to build next."

Avoid upgrades that are only +5% damage, +3% health, slightly faster production. Small stat upgrades are acceptable, but the best upgrades should create strategy shifts.

---

## 18. Research

The wizard tower is the primary place where upgrades become active.

Possible research model: player finds upgrade choices in the world → upgrade is brought back, unlocked, or stored → player spends resources/time at tower to research it → upgrade changes units, economy, wizard, or tower.

This creates a reason to return to base after exploration.

Research should have opportunity cost: time, resources, limited slots, mutually exclusive choices, class-specific requirements.

---

## 19. Procedural Map Generation

Procedural generation should support readable strategy, not random chaos. The map should feel authored even when generated.

Recommended generation hierarchy:

1. Choose map biome/theme
2. Generate terrain height/elevation
3. Generate primary road network
4. Place player spawn region
5. Place base plot candidates
6. Place main objective site
7. Place secondary content plots
8. Place resource clusters
9. Place enemy camps and patrol routes
10. Place merchants, quests, bosses, and landmarks
11. Validate connectivity and difficulty pacing

The road system is central. Roads should guide exploration, connect major content, create natural routes for enemies, help procedural maps feel intentional, support branching choices, and occasionally form grid-like or hub-like structures depending on map type.

All important content should connect to or branch from roads. Content does not need to sit directly on roads, but roads should help the player discover it.

---

## 20. Terrain and Elevation

Terrain should create tactical decisions.

Elevation levels: low ground, medium ground, high ground, peak ground.

Possible gameplay effects: high ground grants vision; high ground improves ranged attacks; low ground may be vulnerable to flooding or ambush; peak ground may block construction or movement; chokepoints make defense easier; open fields favor mobile or large armies.

Terrain types may include: forest, swamp, mountain, ruins, plains, corruption, snow, lava or ashland, magical wasteland.

Terrain must remain readable. Players should quickly understand where units can move, build, and fight.

---

## 21. Roads

Roads are a major procedural and gameplay pillar.

Roads should: connect important locations, create exploration routes, help enemies organize attacks, allow faster movement, give maps structure, make scouting decisions more legible.

Road types may include: main road, broken road, ancient road, forest path, mountain pass, enemy road, magical leyline path.

Possible road mechanics: units move faster on roads; roads provide limited vision; enemy waves use roads; merchants travel along roads; road intersections are likely content points; some upgrades improve road control.

Roads should create both safety and danger. A road helps the player navigate, but it may also guide enemies toward the base.

---

## 22. Content Plots

Content plots are explorable map locations connected to roads or road branches.

Types: ruins, merchant camps, quest locations, enemy camps, boss arenas, resource nodes, shrines, caves, abandoned towers, villages, magical anomalies, relic sites.

Content plots should offer: risk, reward, choice, narrative flavor, upgrade opportunities.

Examples:

- A ruined chapel guarded by undead, rewarding a healing upgrade
- A trapped crystal mine that provides rare mana income
- A merchant camp offering class-specific upgrades
- A cursed grove that strengthens night enemies unless cleansed
- A sealed boss arena that unlocks a tier 3 unit

---

## 23. Quests and Merchants

Quests and merchants should support the run, not distract from it.

Quest examples: defend a stranded caravan; cleanse a shrine; recover a lost relic; escort a magical creature; destroy a nearby enemy camp; gather rare essence; survive an ambush.

Merchant examples: sells upgrades; sells temporary units; sells map information; sells defensive structures; trades one resource for another; offers cursed bargains.

Merchants should encourage exploration and create interesting decisions.

---

## 24. Enemy Pressure

The enemy threat has two layers.

**Constant Trickle** — small groups of enemies pressure the player regularly. Purpose: prevent total turtling, test defenses, keep the map feeling hostile, force scouting and preparation.

**Organized Assault Waves** — larger attacks arrive at known or semi-known intervals. Purpose: create run rhythm, test base layout, reward preparation, escalate tension.

Enemy attacks should feel organized, not random. Enemies may: follow roads, scout the player, attack from multiple directions, target economy, target defenses, siege the tower, attack at night, use weather or terrain advantages.

---

## 25. Day/Night Cycle

Day/night should affect gameplay meaningfully.

**Day**: better vision, safer exploration, stronger economy, more merchant activity, weaker undead or shadow enemies.

**Night**: reduced vision, stronger enemy attacks, more ambushes, certain classes become stronger, special resources appear, bosses or events activate.

Night should feel dangerous but rewarding. The player should prepare for night and use day to make progress.

---

## 26. Weather

Weather should add variation and tactical texture.

Examples: rain, storm, fog, snow, wind, magical eclipse, ashfall, blood moon.

Possible gameplay effects: rain slows fire effects but boosts nature magic; storms boost lightning magic; fog reduces vision; snow slows movement; wind affects projectiles or flying units; blood moon strengthens enemies; magical eclipse alters spell costs or mana generation.

Weather should be readable and communicated clearly. Avoid weather that feels arbitrary or purely cosmetic once implemented.

---

## 27. Boss Fights

Boss fights should be intricate but still RTS-compatible.

Bosses may be: map objective bosses, optional upgrade bosses, class-specific bosses, night bosses, region bosses.

Boss fights should involve: positioning, army composition, wizard spell usage, terrain awareness, adds or summoned enemies, phase changes, objective interactions.

Bosses should not simply be giant health bars.

Examples:

- A necromancer boss raising fallen units
- A storm dragon controlling weather
- A stone titan vulnerable only after destroying anchors
- A forest spirit that shifts terrain and summons roots
- A demon gate that must be sealed while waves spawn

---

## 28. Map and Objective Variation

Each run should combine: a map type, a biome, a procedural layout, a class, a selected objective, randomized upgrades, dynamic enemy pressure.

Map examples: forest crossroads, mountain pass, haunted marsh, ruined kingdom, frozen valley, volcanic wasteland, arcane desert, corrupted wildland.

Objective examples: defeat the region boss; destroy enemy citadels; seal three portals; survive the final siege; recover relic fragments; complete a tower ritual; cleanse corrupted shrines; escort the wizard to an ancient nexus.

The same map should feel different with different objectives and classes.

---

## 29. Tactical Pillars

The game should reward: scouting, base placement, terrain use, defense planning, timing pushes between waves, upgrade synergy, class mastery, risk assessment, road control, objective prioritization.

The game should avoid relying only on: APM, unit spam, hidden math, pure stat scaling, overwhelming UI complexity.

---

## 30. Design Priorities

**Priority 1: Core playable loop** — wizard movement, procedural map, base plot selection, tower placement, basic economy, basic unit production, enemy trickle, enemy wave, win/loss state.

**Priority 2: Strategic depth** — terrain and elevation, road-connected content, upgrade discovery, tower research, class-specific units, better enemy attack logic.

**Priority 3: Replayability** — multiple classes, multiple objectives, merchants and quests, boss fights, weather and day/night systems, more map types.

**Priority 4: Atmosphere and polish** — illustrated visual identity, audio atmosphere, VFX, UI polish, narrative flavor, advanced procedural variety.

---

## 31. Non-Goals for Early Development

Do not prioritize these until the core loop is fun:

- Competitive multiplayer
- Massive unit counts
- Full city-builder economy
- Complex diplomacy
- Deep story campaign
- Dozens of resources
- Fully simulated ecology
- Excessive unit micromanagement
- Large tech trees before class identity works
- Cosmetic polish before gameplay clarity

---

## 32. Technical Stack

Current intended stack:

- **Engine**: Godot
- **Language**: GDScript unless otherwise specified
- **Game type**: Real-time strategy roguelike
- **Presentation**: Stylized 3D or 2.5D with illustrated fantasy direction
- **Target**: PC-first

Agents should follow existing project structure and Godot conventions already present in the repository.

Technical priorities: keep systems modular; prefer data-driven definitions for units, upgrades, classes, maps, and objectives; make procedural generation debuggable; make combat and economy easy to tune; avoid hardcoding class-specific behavior unless the system explicitly requires it; build small playable slices before expanding content volume.

Important data types likely needed: class definition, unit definition, building definition, upgrade definition, map biome definition, objective definition, enemy wave definition, content plot definition, resource node definition.

---

## 33. Agent Development Guidelines

When an AI agent works on this project, it should preserve the core identity: **wizard-led roguelike RTS with exploration, base placement, survival pressure, procedural roads, upgrades, and objective completion.**

Agents should ask:

- Does this support the core loop?
- Does this create an interesting player decision?
- Does this improve readability?
- Does this reinforce the wizard fantasy?
- Does this help replayability?
- Is this scoped appropriately for the current development stage?

Agents should avoid:

- Adding disconnected systems
- Building content before systems can support it
- Creating generic RTS mechanics without wizard/class flavor
- Overcomplicating economy or UI
- Making maps random without strategic structure
- Prioritizing polish over playable decisions

---

## 34. Current Design Pillars

**Pillar 1: The Wizard Matters** — the wizard is not just a commander icon. The wizard explores, fights, researches, and anchors the player's identity.

**Pillar 2: The Tower Matters** — the wizard tower is the heart of the run. It is home, research center, magical fortress, and loss condition.

**Pillar 3: The Map Matters** — the map is not a backdrop. Roads, elevation, chokepoints, resources, and content plots drive strategy.

**Pillar 4: The Base Location Matters** — settling is a major strategic commitment. Base plots should create meaningful tradeoffs.

**Pillar 5: Upgrades Change the Run** — roguelike upgrades should push the player toward new strategies, not just make numbers bigger.

**Pillar 6: Enemies Apply Pressure** — the player should never feel completely safe. Trickle attacks and waves force preparation and expansion timing.

**Pillar 7: Classes Change How You Play** — each class should alter the player's economy, army, exploration, defense, and upgrade priorities.

---

## 35. Example Run

The player chooses the Necromancer.

They spawn on the edge of a haunted forest road with the wizard and a small group of weak servants. They scout along the road and discover three possible base plots: a defensible hill with poor resources; a rich graveyard near enemy patrols; a crossroads with strong expansion potential but many attack angles.

The player chooses the graveyard. They build the wizard tower and begin gathering bone and mana. Early enemies attack at night, but their corpses fuel the necromancer's army.

The player explores a ruined chapel and earns a choice between three upgrades: skeletons revive once after death; the wizard gains a corpse explosion spell; the tower generates mana from nearby graves.

The player researches corpse explosion at the tower.

Later, organized waves begin attacking down the main road. The player builds bone walls and raises disposable units to slow enemies. After stabilizing, they push toward a corrupted mausoleum, defeat an elite guardian, unlock a tier 2 bone knight, and prepare for the final objective: sealing three death portals before the Blood Moon wave destroys the tower.

The run ends when the player either seals the portals or loses the wizard/tower.

---

## 36. Short Version for Agents

Wizard RTS is a roguelike RTS about a wizard founding a tower in a hostile procedural fantasy map. The player explores, chooses a base location, builds economy and defenses, survives enemy pressure, discovers upgrades, and completes a run objective. The run fails if the wizard or tower dies.

Core features:

- Wizard-centered RTS gameplay
- Procedural road-based maps
- Meaningful base placement
- Class-specific units and mechanics
- Micromanageable levels: some units obey precisely, others only take crude orders and fight their own way
- Roguelike upgrades researched at the tower
- Day/night and weather affecting gameplay
- Enemy trickle plus organized waves
- Terrain, elevation, chokepoints, and roads
- Content plots with quests, merchants, bosses, and rewards
- Multiple maps and randomized objectives

---

## 37. Artwork Generation Pipeline

The art direction in Section 6 is the target. This section is the honest status of the tooling meant to produce it, as of 2026-08-19: **it needs massive improvement, and animation is the single largest gap.** Read this before generating more art of any kind — more volume through the current pipeline is not the fix.

### Current state

Two separate, disconnected generation pipelines exist:

- **A 3D pipeline** (`tools/prop_pipeline/`, Meshy text-to-3D/image-to-3D → Blender post-process → GLB). Built against `scripts/map/map_3d_renderer.gd`, which is a **prototyping tool, not the shipping renderer** (confirmed in `PROJECT_BRIEF.md`). Over 100 props were generated through it for one biome before that distinction was caught — none of it was ever visible in the actual game, because the actual game doesn't load that scene. Even where the output was later salvaged into the real 2D game as flat sprite crops, the underlying 3D-mesh-plus-outline technique consistently fails to match the Section 6 art direction as well as real 2D painted art does — confirmed by direct side-by-side comparison, not assumption.
- **A 2D pipeline** (`tools/pixellab_asset_generator.py`, via PixelLab). This is the pipeline that has actually shipped production art — KON unit, building, and combat-FX sprites live under `assets/generated/pixellab/`. It also produced a complete, on-style, high-quality isometric terrain-tile batch for the DARK_FOREST_FRONTIER_V2 biome that sat fully generated and completely unreviewed for roughly four months before anyone noticed it existed.

Both pipelines write into folder names (`assets_game/props/{trees,rocks,ruins,decor}`) that the runtime's 2D sprite scanner (`scripts/assets/asset_registry.gd`) also scans by file extension. This caused real bugs: leftover Meshy debug textures (normal maps, raw JPEG exports) sitting in those folders got picked up as if they were flat sprite art. Found and cleaned up once; nothing currently stops it from happening again on the next 3D-pipeline run.

### Animation: unsolved, not deferred

Per `PROJECT_BRIEF.md`: **"animation is unsolved (only placeholder root-motion clips, no rig library)."** Only one unit (Oaven Spear) has ever been manually bridged from a generation pipeline into actual working 2D gameplay animation. Everything else runs on placeholder motion.

This is not a polish-phase item. Section 15 requires units to be readable by "animation style" as one of four defining traits, and Section 16 expects each class's roster to carry a distinct identity through combat. Neither is achievable with zero real animation coverage. Any pipeline work going forward needs to treat **idle, walk, attack, cast, and death coverage per unit** as a first-class deliverable of the pipeline, not a follow-up task after a static sprite looks good in a thumbnail.

### What "massive improvement" means here

- **Pick one pipeline as the default for new gameplay art and say so explicitly.** The 2D/PixelLab path is the one with a track record of shipping real assets and the one consistent with the "staying 2D" decision already made for units — new terrain/prop/unit work should default there, not to Meshy, unless there's a specific reason (e.g. marketing renders) to reach for 3D again.
- **Build the animation pipeline before generating more static art volume.** A large, well-styled, unanimated roster does not move the game closer to shippable — the Oaven Spear precedent is the only proof this can work end-to-end, and it hasn't been repeated.
- **Separate the two pipelines' output folders permanently** so a 3D-pipeline run can never again pollute the 2D system's scanned folders. This is a small fix that has already caused real bugs twice.
- **Require an in-engine verification step before any generation batch is called done.** This session's repeated failure mode was generating and style-reviewing assets in isolation (thumbnails, single-object renders) without ever confirming they rendered correctly, at the right scale, in the actual running scene. A batch isn't finished until someone has looked at it in the real game.
- **Treat unreviewed output as a liability, not a backlog.** The four-month-old terrain batch sitting untouched was pure waste — fully paid for, on-style, and doing nothing. Generation and review need to be the same cycle, not two cycles that can silently drift apart.

Every feature should support exploration, settlement, survival, upgrading, and objective completion.

---

## 38. Micromanageable Levels

Not every unit answers to the same degree of control. Some units can be fully micromanaged with immediate, precise responsiveness. Others accept only primitive commands and otherwise fight their own way — defending but never advancing, or committing to an attack order that cannot be called off.

This is a core mechanic, not a difficulty setting and not an AI quality problem. A unit that ignores half of your orders is not a broken unit; it is a unit whose **control cost is part of its price**.

Why it exists:

- **It is how scale stays tactical.** Section 5 targets hundreds of units on screen while explicitly refusing high-APM play. Controllability is the lever that makes both true at once. If every unit in a 300-unit army were fully responsive, the skill ceiling would become raw APM by default, no matter how good the control tooling is. Making most of the army semi-autonomous puts the player's attention on the few units that actually reward it.
- **It is faction fantasy made mechanical.** Kon commands spliced hybrids of a species his own kin sealed away. Obedience should visibly degrade the closer a unit sits to the forbidden. Cheap subservient hybrids take orders; the things further down the roster increasingly do not.
- **It creates a trade-off axis that is not power.** A unit can be strong *and* awkward. That makes roster decisions interesting without making units strictly better or worse than each other — the failure mode Section 29 warns about as "pure stat scaling".

**Intelligence** is the stat, shown on the unit card, on a three-point scale. Decided 2026-08-31 and implemented:

- **1 — Feral.** Set behaviour that cannot be changed. Player orders are refused outright.
- **2 — Leashed.** Can be given move commands while no enemy is within its aggro range. Once something comes inside that range it drops the order and reverts to its set behaviour.
- **3 — Bound.** Fully micromanageable. Every order, at any time.

Intelligence is a **stat, not a fixed trait** — it varies, and upgrades raise it. Observer Vault research (`observer_command`, 2 ranks) adds +1 per rank, capped at 3. Kon's observer magic is what lets him direct the forbidden at all, so buying obedience belongs in that building.

**Aggro range** is the companion stat: how far an enemy can be before the unit engages it automatically, in cells. It defines the leash for Intelligence 2 and it drives auto-engagement for every unit at every level. Before this it was an implicit `max(attack_range × 1.5, 256px)` buried in the combat system with no design control over it at all.

The two stats read together: aggro range says when a unit starts fighting on its own, intelligence says whether you can stop it.

Design rules:

- Intelligence and aggro range must be **visible before purchase**, on the unit card. A control level is a cost, and costs have to be legible.
- Intelligence should be **stable and knowable**, never random. Players plan around it.
- Evolution may **change** a unit's intelligence, in either direction. A hybrid that grows stronger while becoming *less* obedient is on-theme, and gives evolution a downside worth weighing rather than being a pure upgrade.
- **Stop is always obeyed**, at every level above Feral. Refusing it would leave the player with no way to call anything off, which reads as a bug rather than as character.
- The wizard is always Intelligence 3. The hero is the one thing the player can rely on absolutely.
- A partially-obeyed order must be **reported**, never silently partial. Ordering a mixed selection where only some units comply has to say so.

The game should avoid: low-controllability units simply feeling unresponsive or broken. The distinction has to read as **character** — the unit straining against the leash, not the game failing to receive an order. Animation, audio and command feedback carry as much of this as the underlying logic does. A Loosed unit should look like it chose to keep fighting.

Open questions:

- Whether control level is a property of the unit, of its current evolution stage, or of its distance from Kon and the Observation Tower — an observer-magic leash, where the army is more obedient near its wizard and more feral far from him.
- Whether the other classes express this axis at all, or whether it belongs to KoN alone as a class identity.
- Whether Intelligence 1 needs more than one "set behaviour". Today a Feral unit simply fights on its own; the doc's original framing also imagined defend-only postures, which would need a stance to sit alongside the stat.
