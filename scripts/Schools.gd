class_name Schools
extends RefCounted

# School enrollment options. Data lives in `data/schools.json`, loaded into
# CATALOG at boot by CatalogLoader. A pet enrolls during 아동기 by
# completing one of the school enrollment actions (Actions.CATALOG entries
# with `sets_school`). While `pet["school"]` is non-null,
# EventManager._tick_economy drains `cost_per_second` from the family
# treasury each game-minute (= each real second). Graduation clears the
# field automatically when the pet leaves 아동기.

static var CATALOG: Dictionary = {}

static func cost_per_second(school_id: String) -> int:
	return int(CATALOG.get(school_id, {}).get("cost_per_second", 0))

static func label(school_id: String) -> String:
	return String(CATALOG.get(school_id, {}).get("label", ""))
