# Generation Provenance

Built-in image generation was used, not the CLI/API fallback.

## Character Source

Create a production character animation source sheet for Kon, a miserable young
adult male life wizard from the supplied reference. Dark illustrated hand-painted
miniature sculpted from wood, clay and stone; black ink outlines; chipped teal
robes; black messy hair; gaunt blue-grey face; glowing cyan eyes; burgundy red
mushrooms on shoulder; wrapped hands and boots; shredded cape. Staff broken into
two separate unequal wooden branches, one in each hand. Six equally spaced
whole-body poses, 3 columns by 2 rows: idle, walking, first long-branch attack,
second short-branch attack, observation casting, collapsed death. Same design,
scale and three-quarter facing-right camera. No text or scenery. Full silhouettes
and staff tips within cells. Transparent background requested.

The first output baked a checkerboard into RGB. A second built-in image edit
preserved the six characters and replaced only that background with flat
magenta RGB255,0,255. The existing Godot chroma shader removes it during baking.

## Spell Source

Production VFX sheet: four isolated effects in a 2x2 grid, no text, scene or
characters. Sinister life wizard; dark hand-painted ink illustration; cyan magic
and crimson fungal spores; splintered wood. Top-left open cyan seal of interwoven
thorn roots and engraved runes, upward wisps. Top-right crimson/turquoise biological
storm with fungal fragments, forked cyan lightning and thorn tornado strands.
Bottom-left cyan all-seeing eye framed by pale root branches and luminous spores.
Bottom-right two cyan staff-strike crescents with wooden splinters. Airy silhouettes,
no cell overlaps; strong ink edges, not clean vector neon. Magenta key requested;
the returned file instead had genuine alpha, verified and preserved unchanged.
