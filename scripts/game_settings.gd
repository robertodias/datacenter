extends RefCounted
const DEFAULT_BINDINGS={"inspect":KEY_Q,"buy":KEY_B,"demolish":KEY_X,"datacenter":KEY_1,"power":KEY_2,"cooling":KEY_3,"contracts":KEY_C,"company":KEY_G,"pause":KEY_SPACE,"speed":KEY_F4}
var fullscreen=false
var resolution=Vector2i(1440,900)
var ui_scale=1.0
var volume=0.7
var sound=true
var music=true
var ambience=true
var auto_pause=true
var reduced_motion=false
var bindings:Dictionary=DEFAULT_BINDINGS.duplicate()
var path="user://settings.cfg"

func _init(qa:bool=false) -> void:
	if qa: path="user://qa_settings.cfg"

func load_settings() -> void:
	var cfg=ConfigFile.new()
	if cfg.load(path)!=OK: return
	fullscreen=bool(cfg.get_value("display","fullscreen",false))
	resolution=cfg.get_value("display","resolution",Vector2i(1440,900))
	if not resolution is Vector2i: resolution=Vector2i(1440,900)
	resolution=resolution.clamp(Vector2i(1152,720),Vector2i(7680,4320))
	ui_scale=clampf(float(cfg.get_value("display","ui_scale",1.0)),0.85,1.25)
	volume=clampf(float(cfg.get_value("audio","volume",0.7)),0,1)
	sound=bool(cfg.get_value("audio","enabled",true))
	music=bool(cfg.get_value("audio","music",true))
	ambience=bool(cfg.get_value("audio","ambience",true))
	auto_pause=bool(cfg.get_value("game","auto_pause",true))
	reduced_motion=bool(cfg.get_value("display","reduced_motion",false))
	var custom=cfg.get_value("controls","bindings",{})
	if custom is Dictionary:
		for action in DEFAULT_BINDINGS:
			if custom.get(action) is int and custom[action]>0: bindings[action]=custom[action]

func save_settings() -> bool:
	var cfg=ConfigFile.new()
	cfg.set_value("display","fullscreen",fullscreen)
	cfg.set_value("display","resolution",resolution)
	cfg.set_value("display","ui_scale",ui_scale)
	cfg.set_value("display","reduced_motion",reduced_motion)
	cfg.set_value("audio","volume",volume)
	cfg.set_value("audio","enabled",sound)
	cfg.set_value("audio","music",music)
	cfg.set_value("audio","ambience",ambience)
	cfg.set_value("game","auto_pause",auto_pause)
	cfg.set_value("controls","bindings",bindings)
	var error=cfg.save(path+".tmp")
	if error!=OK: return false
	return DirAccess.rename_absolute(path+".tmp",path)==OK

func bind_action(action:String,key:int) -> String:
	if not DEFAULT_BINDINGS.has(action): return "Unknown action."
	if key in [KEY_ESCAPE,KEY_F11,KEY_F5,KEY_F9,KEY_TAB,KEY_ENTER]: return "That key is reserved for menus or display controls."
	for other in bindings:
		if other!=action and bindings[other]==key: return "Already used for "+other+". Choose another key."
	bindings[action]=key
	return ""

func key_label(action:String) -> String:
	return OS.get_keycode_string(bindings.get(action,0))

func action_for(event:InputEventKey) -> String:
	if event.alt_pressed or event.ctrl_pressed or event.meta_pressed: return ""
	for action in bindings:
		if event.keycode==bindings[action]: return action
	return ""
