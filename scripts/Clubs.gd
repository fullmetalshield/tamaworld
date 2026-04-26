class_name Clubs
extends RefCounted

# Club catalogue. Data lives in `data/clubs.json`, loaded into CATALOG and
# NPC_NAMES at boot by CatalogLoader. The "동호회 활동하기" action presents
# 3 random clubs from this pool; selecting one appends to `pet["clubs"]`.
# The per-club activity rows pick a random member name (from NPC_NAMES) to
# bond with on completion — `pet["bonds"][name]` increments. Same name pool
# is reused across activities so repeat encounters compound the bond rather
# than spawning a brand-new "person" each time.

static var CATALOG: Dictionary = {}
static var NPC_NAMES: Array = []

static func has(id: String) -> bool:
	return CATALOG.has(id)

static func label(id: String) -> String:
	return String(CATALOG.get(id, {}).get("label", id))

static func activity_label(id: String) -> String:
	return String(CATALOG.get(id, {}).get("activity_label", "동호회 활동"))

static func progress_label(id: String) -> String:
	return String(CATALOG.get(id, {}).get("progress_label", "활동 중"))

static func color(id: String) -> Color:
	return CATALOG.get(id, {}).get("color", Color(0.95, 0.86, 0.88, 1))

# Returns up to 3 random club ids the pet hasn't already joined. Falls back
# to repeats only if the pet has joined too many to fill a fresh trio.
static func random_three(exclude: Array = []) -> Array:
	var pool: Array = CATALOG.keys()
	var fresh: Array = pool.filter(func(id): return not (id in exclude))
	if fresh.size() < 3:
		fresh = pool
	fresh.shuffle()
	return fresh.slice(0, min(3, fresh.size()))

static func random_member_name() -> String:
	if NPC_NAMES.is_empty():
		return "친구"
	return NPC_NAMES[randi() % NPC_NAMES.size()]
