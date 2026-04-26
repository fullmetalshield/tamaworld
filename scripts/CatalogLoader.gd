extends Node

# Autoload (registered before EventManager). Reads data/*.json at boot,
# parses hex colour strings into Color, and populates the static CATALOG
# fields on Actions / Clubs / Schools / Jobs. Then runs cross-reference
# validation so structural errors (unknown phase ids, dangling sets_school
# refs, missing starting_job, invalid colour hex) surface at boot via
# push_error rather than crashing or silently mis-rendering mid-game.
#
# Adding a new system: drop another data/<name>.json + matching
# `static var CATALOG` on the GDScript side, add a `_load_<name>` call here,
# and extend `_validate` if there are cross references worth catching.

const ACTIONS_PATH := "res://data/actions.json"
const CLUBS_PATH := "res://data/clubs.json"
const SCHOOLS_PATH := "res://data/schools.json"
const JOBS_PATH := "res://data/jobs.json"

func _ready() -> void:
	_load_all()
	_validate()

func _load_all() -> void:
	_load_actions()
	_load_clubs()
	_load_schools()
	_load_jobs()

func _load_actions() -> void:
	var catalog: Dictionary = _read_catalog(ACTIONS_PATH)
	if catalog.is_empty():
		return
	for id in catalog:
		var entry: Variant = catalog[id]
		if entry is Dictionary:
			_parse_color_field(entry, id, "Actions")
	Actions.CATALOG = catalog

func _load_clubs() -> void:
	var data: Variant = _read_json(CLUBS_PATH)
	if not (data is Dictionary):
		return
	var catalog: Dictionary = data.get("catalog", {})
	for id in catalog:
		var entry: Variant = catalog[id]
		if entry is Dictionary:
			_parse_color_field(entry, id, "Clubs")
	Clubs.CATALOG = catalog
	var names: Variant = data.get("npc_names", [])
	if names is Array:
		Clubs.NPC_NAMES = names

func _load_schools() -> void:
	var catalog: Dictionary = _read_catalog(SCHOOLS_PATH)
	if not catalog.is_empty():
		Schools.CATALOG = catalog

func _load_jobs() -> void:
	var data: Variant = _read_json(JOBS_PATH)
	if not (data is Dictionary):
		return
	Jobs.CATALOG = data.get("catalog", {})
	Jobs.STARTING_JOB = String(data.get("starting_job", ""))

# Reads a `{"catalog": {...}}` wrapped JSON file and returns the catalog
# Dictionary, or an empty dict if anything went wrong (errors already
# pushed by _read_json).
func _read_catalog(path: String) -> Dictionary:
	var data: Variant = _read_json(path)
	if data is Dictionary and data.has("catalog"):
		var catalog: Variant = data["catalog"]
		if catalog is Dictionary:
			return catalog
	push_error("CatalogLoader: %s missing 'catalog' object" % path)
	return {}

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("CatalogLoader: missing %s" % path)
		return null
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("CatalogLoader: failed to parse %s" % path)
	return parsed

func _parse_color_field(entry: Dictionary, entry_id: String, source: String) -> void:
	if not entry.has("color"):
		return
	var raw: Variant = entry["color"]
	if raw is Color:
		return  # already converted (e.g. hot-reloaded)
	if not (raw is String):
		push_error("%s[%s]: color field must be a hex string, got %s" % [source, entry_id, typeof(raw)])
		return
	var hex: String = String(raw)
	if not Color.html_is_valid(hex):
		push_error("%s[%s]: invalid color hex '%s'" % [source, entry_id, hex])
		return
	entry["color"] = Color.html(hex)

# Cross-reference checks: catch structural issues at boot rather than mid
# gameplay. Pushes errors but does not abort — the game still loads with
# whatever data parsed.
func _validate() -> void:
	var phase_ids: Array = []
	for p in Stats.PHASES:
		phase_ids.append(String(p["id"]))

	for id in Actions.CATALOG:
		var entry: Dictionary = Actions.CATALOG[id]
		for phase_id in entry.get("phases", []):
			if not (String(phase_id) in phase_ids):
				push_error("Actions[%s]: unknown phase id '%s'" % [id, phase_id])
		var school_id: String = String(entry.get("sets_school", ""))
		if school_id != "" and not Schools.CATALOG.has(school_id):
			push_error("Actions[%s]: sets_school '%s' not in Schools.CATALOG" % [id, school_id])
		var picker: String = String(entry.get("opens_picker", ""))
		if picker != "" and picker != "club":
			push_error("Actions[%s]: unknown opens_picker target '%s'" % [id, picker])

	if Jobs.STARTING_JOB != "" and not Jobs.CATALOG.has(Jobs.STARTING_JOB):
		push_error("Jobs.STARTING_JOB '%s' not in Jobs.CATALOG" % Jobs.STARTING_JOB)
