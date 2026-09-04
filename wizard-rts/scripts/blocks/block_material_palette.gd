class_name BlockMaterialPalette
extends RefCounted

# The arcane-stone skin: what each authored material role looks like.
#
# Every block used to be one flat vertex colour in a single MultiMesh, which is
# why the citadel read as a grey model rather than a building. The reference art
# is carried almost entirely by ONE thing the old setup could not do: the
# windows, domes and crystals GLOW. Emission is not decoration here, it is the
# whole silhouette at night -- a dark teal mass with cyan light coming out of it.
#
# Godot's StandardMaterial3D takes one emission value per material, not per
# instance, so blocks are grouped into FAMILIES and each family gets its own
# MultiMesh and its own material. Six draw calls instead of one, which is a
# trade worth making: it is six regardless of whether the structure is a
# gatehouse or a 104,000-block citadel.
#
# Material names come from three different authoring schemas, so the lookup
# covers all of them and falls back to stone rather than to magenta -- an
# unknown material in a castle is far more likely to be masonry than a bug.

enum Family { STONE, PALE_STONE, TIMBER, METAL, GLASS, CRYSTAL, ROOF }

# role/material name -> family. Lower-cased on lookup, so the composition
# schema's `exterior_wall` and 1.1's `TOWER_STONE` both land correctly.
const FAMILY_BY_NAME := {
	# --- schema 1.0 / 1.1
	"stone_brick": Family.STONE,
	"mossy_stone": Family.STONE,
	"black_stone": Family.STONE,
	"ruin_stone": Family.STONE,
	"tower_stone": Family.STONE,
	"dark_stone": Family.STONE,
	"magic_stone": Family.CRYSTAL,
	"bone": Family.PALE_STONE,
	"timber": Family.TIMBER,
	"metal": Family.METAL,
	"metal_gate": Family.TIMBER,
	"glass": Family.GLASS,
	"gate": Family.TIMBER,
	"void_decor": Family.STONE,
	"empty": Family.STONE,
	# --- composition schema roles
	"foundation": Family.STONE,
	"exterior_wall": Family.STONE,
	"keep_wall": Family.STONE,
	"tower_wall": Family.STONE,
	"exterior_trim": Family.PALE_STONE,
	"interior_floor": Family.PALE_STONE,
	"stair": Family.PALE_STONE,
	"ramp": Family.PALE_STONE,
	"arch": Family.PALE_STONE,
	"roof": Family.ROOF,
	"crystal": Family.CRYSTAL,
	"marker": Family.CRYSTAL,
}

# Weathered blue-teal masonry, pale worn paving, dark timber, cold iron, and
# two emissive families for the glass and the mana crystal.
const FAMILY_ALBEDO := {
	Family.STONE: Color("#33525E"),
	Family.PALE_STONE: Color("#6E8C93"),
	Family.TIMBER: Color("#4A3626"),
	Family.METAL: Color("#232A31"),
	Family.GLASS: Color("#4FE3DC"),
	Family.CRYSTAL: Color("#2FD3CC"),
	Family.ROOF: Color("#2B4055"),
}
# Tuned down from 1.5/2.2 after the first render: a whole observatory crown of
# glass at that strength blew out to flat white, which loses the panelling the
# emission was meant to show off. The reference art glows, it does not burn.
const FAMILY_EMISSION := {
	Family.GLASS: 0.65,
	Family.CRYSTAL: 1.1,
}
const FAMILY_ROUGHNESS := {
	Family.STONE: 0.95,
	Family.PALE_STONE: 0.9,
	Family.TIMBER: 0.85,
	Family.METAL: 0.45,
	Family.GLASS: 0.15,
	Family.CRYSTAL: 0.25,
	Family.ROOF: 0.8,
}
const FAMILY_METALLIC := {
	Family.METAL: 0.7,
}

static func family_for(material_name: StringName) -> Family:
	return FAMILY_BY_NAME.get(str(material_name).to_lower(), Family.STONE)

static func albedo_for(family: Family) -> Color:
	return FAMILY_ALBEDO.get(family, Color("#33525E"))

# Blocks still carry a per-instance colour so a family is not uniformly flat --
# a wall of one exact tone reads as a solid, not as masonry. The variation is
# derived from the cell position rather than random, so a rebuilt structure
# looks identical to the one before it.
static func instance_tint(family: Family, cell: Vector3i) -> Color:
	var base := albedo_for(family)
	if family == Family.GLASS or family == Family.CRYSTAL:
		return base
	var noise: int = (cell.x * 73 + cell.y * 151 + cell.z * 37) % 11
	var shade: float = 1.0 + (float(noise) - 5.0) * 0.018
	return Color(base.r * shade, base.g * shade, base.b * shade, base.a)

static func make_material(family: Family) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = float(FAMILY_ROUGHNESS.get(family, 0.9))
	material.metallic = float(FAMILY_METALLIC.get(family, 0.0))
	var emission: float = float(FAMILY_EMISSION.get(family, 0.0))
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = albedo_for(family)
		material.emission_energy_multiplier = emission
		# Glass reads as lit from within rather than as a painted panel.
		material.rim_enabled = true
		material.rim = 0.6
	return material
