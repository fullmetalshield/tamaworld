class_name PetStore
extends RefCounted

# Persists a lineage of tamagotchi pets. The first pet created is the
# protagonist; every subsequent pet is linked via `parent_ids` / `spouse_id`.

const SAVE_PATH := "user://pets.json"
const GIVEN_NAMES := [
	"루피", "모모", "콩이", "보리", "초코", "뚱이", "호야", "밤이",
	"삐삐", "달이", "별이", "솜이", "두부", "호떡", "복실", "쫀득",
	"살구", "참외", "메롱", "방울", "포실", "꼬물", "만두", "빵이"
]

static var _pets: Array = []
static var _loaded: bool = false

# --- load/save -----------------------------------------------------------

static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if FileAccess.file_exists(SAVE_PATH):
		var text := FileAccess.get_file_as_string(SAVE_PATH)
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Array:
			_pets = parsed
	_migrate_pets()

# Backfill missing fields on pets loaded from older save files.
static func _migrate_pets() -> void:
	var changed := false
	for pet in _pets:
		if not pet.has("stats"):
			pet["stats"] = Stats.random_base_stats()
			changed = true
		if not pet.has("lifespan_minutes"):
			pet["lifespan_minutes"] = Stats.random_lifespan_minutes()
			changed = true
		if not pet.has("died_at_minutes"):
			pet["died_at_minutes"] = null
			changed = true
	if changed:
		persist()

static func create_protagonist(name: String) -> Dictionary:
	var pet := generate_random_pet({"given_name": name})
	pet["born_at_minutes"] = 0
	add_pet(pet)
	return pet

static func persist() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_pets))

static func reset() -> void:
	_pets = []
	_loaded = false
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

# --- queries -------------------------------------------------------------

static func all() -> Array:
	ensure_loaded()
	return _pets

static func protagonist() -> Dictionary:
	var list := all()
	return list[0] if not list.is_empty() else {}

static func find_by_id(id: String) -> Dictionary:
	for p in all():
		if p.get("id", "") == id:
			return p
	return {}

static func family_surname() -> String:
	return protagonist().get("body_id", "")

static func spouse_of(pet: Dictionary) -> Dictionary:
	var sid: String = pet.get("spouse_id", "") if pet.get("spouse_id") != null else ""
	return find_by_id(sid)

static func children_of(parent: Dictionary) -> Array:
	var pid: String = parent.get("id", "")
	return all().filter(func(p): return pid in p.get("parent_ids", []))

# --- mutations -----------------------------------------------------------

static func add_pet(pet: Dictionary) -> void:
	ensure_loaded()
	_pets.append(pet)
	persist()

static func marry(a_id: String, b_id: String, at_game_minutes: int) -> void:
	var a := find_by_id(a_id)
	var b := find_by_id(b_id)
	if a.is_empty() or b.is_empty():
		return
	a["spouse_id"] = b_id
	b["spouse_id"] = a_id
	a["married_at_minutes"] = at_game_minutes
	b["married_at_minutes"] = at_game_minutes
	persist()

# --- factories -----------------------------------------------------------

static func generate_random_pet(overrides: Dictionary = {}) -> Dictionary:
	var all_chars := Characters.all()
	var body: Dictionary = all_chars[randi() % all_chars.size()]
	var eyes: Dictionary = all_chars[randi() % all_chars.size()]
	var pet := {
		"id": make_uid(),
		"given_name": GIVEN_NAMES[randi() % GIVEN_NAMES.size()],
		"body_id": body.get("id", ""),
		"eyes_id": eyes.get("id", ""),
		"color": body.get("color", "#ffffff"),
		"parent_ids": [],
		"spouse_id": null,
		"born_at_minutes": 0,
		"married_at_minutes": null,
		"stats": Stats.random_base_stats(),
		"lifespan_minutes": Stats.random_lifespan_minutes(),
		"died_at_minutes": null,
	}
	for k in overrides:
		pet[k] = overrides[k]
	return pet

static func make_uid() -> String:
	var s := ""
	for i in 12:
		s += "%x" % (randi() % 16)
	return s
