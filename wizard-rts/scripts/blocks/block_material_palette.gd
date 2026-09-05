class_name BlockMaterialPalette
extends RefCounted

# Authored material roles select painted stone, timber, iron and leaded glass.
# A shared texture is projected at a consistent world scale across block faces.
# Material families remain batched; architectural dressings are separate batches.
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

static func make_material(family: Family) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/structures/arcane_stone/painted_structure.gdshader")
	material.set_shader_parameter("masonry", preload("res://assets/structures/arcane_stone/masonry_painted.png"))
	material.set_shader_parameter("family", int(family))
	var tint := Color.WHITE
	if family == Family.PALE_STONE:
		tint = Color(1.25, 1.25, 1.18)
	elif family == Family.ROOF:
		tint = Color(0.48, 0.65, 0.68)
	material.set_shader_parameter("tint", tint)
	return material
