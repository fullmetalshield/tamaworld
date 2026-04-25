extends Node

# Autoload. Loads translations/strings.json at startup and registers each
# locale column with TranslationServer so `tr("KEY")` resolves anywhere.
# JSON is used (not CSV) so Godot does not auto-import the source file,
# which keeps the same data file available in editor and exported builds.

const JSON_PATH := "res://translations/strings.json"
const DEFAULT_LOCALE := "ko"

func _ready() -> void:
	_load_json()
	TranslationServer.set_locale(DEFAULT_LOCALE)

func _load_json() -> void:
	if not FileAccess.file_exists(JSON_PATH):
		push_warning("I18n: %s not found" % JSON_PATH)
		return
	var text := FileAccess.get_file_as_string(JSON_PATH)
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary):
		push_warning("I18n: parse failed")
		return
	var per_locale: Dictionary = {}
	for key in data:
		var entry: Variant = data[key]
		if not (entry is Dictionary):
			continue
		for loc in entry:
			if not per_locale.has(loc):
				var t := Translation.new()
				t.locale = loc
				per_locale[loc] = t
			per_locale[loc].add_message(key, entry[loc])
	for t in per_locale.values():
		TranslationServer.add_translation(t)
