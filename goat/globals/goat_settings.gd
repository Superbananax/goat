class_name GoatSettings
extends Node

"""
Helps with handling Godot Engine settings relevant to GOAT.
"""

signal value_changed (section, key)

const SETTINGS_FILE_NAME := "user://settings.cfg"
# Each entry contains: section name, key name, default value
const DEFAULT_VALUES := [
	["graphics", "fullscreen_enabled", true],
	["graphics", "glow_enabled", true],
	["graphics", "reflections_enabled", true],
	["graphics", "shadows_enabled", true],
	["sound", "music_volume", 0.0],
	["sound", "effects_volume", 0.0],
	["controls", "mouse_sensitivity", 0.3],
]

# If enabled, settings will be saved to file when changed
var autosave := true

var _settings_file := ConfigFile.new()


func _ready():
	_settings_file.load(SETTINGS_FILE_NAME)
	
	for entry in DEFAULT_VALUES:
		var section =  entry[0]
		var key = entry[1]
		var value = entry[2]
		# Add detailed signals for each section and key
		add_user_signal("value_changed_{}_{}".format([section, key], "{}"))
		# If settings file doesn't have the section/key yet,
		# add it with the default value
		if _settings_file.get_value(section, key) == null:
			_settings_file.set_value(section, key, value)
	
	_settings_file.save(SETTINGS_FILE_NAME)
	
	# Connect settings to global handlers
	var settings_signals_handlers = {
		"value_changed_graphics_shadows_enabled": "_on_shadows_settings_changed",
		"value_changed_graphics_reflections_enabled": "_on_camera_settings_changed",
		"value_changed_graphics_glow_enabled": "_on_camera_settings_changed",
		"value_changed_graphics_fullscreen_enabled": "_on_fullscreen_settings_changed",
		"value_changed_sound_music_volume": "_on_music_settings_changed",
		"value_changed_sound_effects_volume": "_on_effects_settings_changed",
	}
	
	for key in settings_signals_handlers:
		connect(key, self, settings_signals_handlers[key])
	
	# Make sure that settings are applied to new nodes
	get_tree().connect("node_added", self, "_on_node_added")
	
	# Make sure that initial values are loaded correctly
	_on_fullscreen_settings_changed()
	_on_music_settings_changed()
	_on_effects_settings_changed()


func get_value(section: String, key: String):
	var value = _settings_file.get_value(section, key)
	assert(value != null)
	return value


func set_value(section: String, key: String, value):
	var previous_value = _settings_file.get_value(section, key)
	if previous_value != value:
		_settings_file.set_value(section, key, value)
		if autosave:
			_settings_file.save(SETTINGS_FILE_NAME)
		emit_signal("value_changed", section, key)
		emit_signal("value_changed_{}_{}".format([section, key], "{}"))


func _on_fullscreen_settings_changed():
	OS.window_fullscreen = get_value("graphics", "fullscreen_enabled")


func _on_music_settings_changed():
	var volume = get_value("sound", "music_volume")
	_set_volume_db("Music", volume)


func _on_effects_settings_changed():
	var volume = get_value("sound", "effects_volume")
	_set_volume_db("Effects", volume)


func _on_shadows_settings_changed():
	for lamp in get_tree().get_nodes_in_group("goat_lamp"):
		_update_single_lamp_settings(lamp)


func _on_camera_settings_changed():
	for camera in get_tree().get_nodes_in_group("goat_camera"):
		_update_single_camera_settings(camera)


func _on_node_added(node: Node):
	if node.is_in_group("goat_lamp"):
		_update_single_lamp_settings(node)
	if node.is_in_group("goat_camera"):
		_update_single_camera_settings(node)


func _update_single_lamp_settings(lamp: Light):
	var shadows_enabled = get_value("graphics", "shadows_enabled")
	lamp.shadow_enabled = shadows_enabled
	# Specular light creates reflections, without shadows they look wrong
	lamp.light_specular = 0.5 if shadows_enabled else 0.0


func _update_single_camera_settings(camera: Camera):
	var reflections_enabled = get_value("graphics", "reflections_enabled")
	var glow_enabled = get_value("graphics", "glow_enabled")
	camera.environment.ss_reflections_enabled = reflections_enabled
	camera.environment.glow_enabled = glow_enabled


func _set_volume_db(bus_name: String, volume: float) -> void:
	"""
	Volume is a value between 0 (complete silence) and 1 (default bus volume).
	It is recalculated to a non-linear value between -80 and 0 dB.
	Using a linear value causes the sound to almost vanish long before the
	volume slider reaches minimum.
	"""
	# Min volume dB
	var M = -80.0
	# Recalculate to <M, 0>, non-linear
	var volume_db = abs(M) * sqrt(2 * volume - pow(volume, 2)) + M
	var bus_id = AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_db(bus_id, volume_db)
