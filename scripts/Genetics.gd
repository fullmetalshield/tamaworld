class_name Genetics
extends RefCounted

# Child gene inheritance.
#
# Each gene is independently rolled from an ancestor pool:
#   - 90% chance from one of the two direct parents (45% each)
#   - 10% chance from deeper ancestors (grandparents, great-grandparents, ...)
#
# This gives heredity with occasional "throwback" traits.

const GENES := ["body_id", "eyes_id", "color"]
const PARENT_BIAS := 0.90

static func create_child(parent_a: Dictionary, parent_b: Dictionary, all_pets: Array, born_at_minutes: int) -> Dictionary:
	var ancestors := _collect_ancestors([parent_a, parent_b], all_pets)
	var child := {
		"id": PetStore.make_uid(),
		"given_name": PetStore.GIVEN_NAMES[randi() % PetStore.GIVEN_NAMES.size()],
		"parent_ids": [parent_a.get("id", ""), parent_b.get("id", "")],
		"spouse_id": null,
		"born_at_minutes": born_at_minutes,
		"married_at_minutes": null,
		"stats": Stats.inherit_stats(parent_a.get("stats", {}), parent_b.get("stats", {})),
		"lifespan_minutes": Stats.random_lifespan_minutes(),
		"died_at_minutes": null,
	}
	for gene in GENES:
		child[gene] = _roll_gene(gene, parent_a, parent_b, ancestors)
	return child

static func _roll_gene(gene: String, p_a: Dictionary, p_b: Dictionary, ancestors: Array) -> Variant:
	var r := randf()
	if r < PARENT_BIAS * 0.5:
		return p_a.get(gene)
	elif r < PARENT_BIAS:
		return p_b.get(gene)
	if ancestors.is_empty():
		return p_a.get(gene) if randf() < 0.5 else p_b.get(gene)
	return ancestors[randi() % ancestors.size()].get(gene)

# Ancestors of the given seed pets, walking up parent_ids, excluding the
# seed pets themselves. Deduplicated.
static func _collect_ancestors(seed: Array, all_pets: Array) -> Array:
	var seen := {}
	var result := []
	var frontier: Array = []
	var seed_ids := {}
	for s in seed:
		seed_ids[s.get("id", "")] = true
		for pid in s.get("parent_ids", []):
			frontier.append(pid)
	while not frontier.is_empty():
		var id: String = frontier.pop_front()
		if seen.has(id) or seed_ids.has(id):
			continue
		seen[id] = true
		for p in all_pets:
			if p.get("id", "") == id:
				result.append(p)
				for gp in p.get("parent_ids", []):
					frontier.append(gp)
				break
	return result
