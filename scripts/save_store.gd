extends RefCounted
## Slot ownership and recovery. Never delete a successful backup before committing a new save.
const Sim=preload("res://scripts/simulation.gd")
var directory="user://saves"
var legacy_path=Sim.SAVE_PATH
var last_error=""
var latest_path=""
var auto_index=0

func _init(qa:bool=false) -> void:
	if qa:
		directory="user://qa_saves"
		legacy_path="user://qa-town.json"
	DirAccess.make_dir_recursive_absolute(directory)
	var cfg=ConfigFile.new()
	if cfg.load(directory+"/index.cfg")==OK:
		latest_path=cfg.get_value("slots","latest","")
		auto_index=int(cfg.get_value("slots","auto_index",0))%3

func remember(path:String) -> void:
	latest_path=path
	var cfg=ConfigFile.new()
	cfg.set_value("slots","latest",latest_path)
	cfg.set_value("slots","auto_index",auto_index)
	cfg.save(directory+"/index.cfg")

func read_metadata(path:String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var json=JSON.new()
	if json.parse(FileAccess.get_file_as_string(path))!=OK or not json.data is Dictionary:
		return {"path":path,"title":path.get_file().get_basename(),"damaged":true,"modified":FileAccess.get_modified_time(path)}
	var data:Dictionary=json.data
	var validator=Sim.new()
	var valid=validator.load_game(path)
	if not valid: return {"path":path,"title":path.get_file().get_basename(),"damaged":true,"modified":FileAccess.get_modified_time(path)}
	var meta:Dictionary=data.get("metadata",{}).duplicate()
	meta.path=path
	meta.title=meta.get("title","Previous town" if path==legacy_path else path.get_file().get_basename())
	meta.company=data.get("company_name","Littlebrook Infrastructure Co.")
	meta.scenario=data.get("scenario_id","littlebrook")
	meta.cash=data.get("cash",0)
	meta.day=int(data.get("hour",0))/24+1
	meta.play_seconds=data.get("play_seconds",0)
	meta.deliveries=data.get("completed",[]).filter(func(id):return id is String and not (id.begins_with("scout_") or id.begins_with("vision_") or id.begins_with("open_"))).size()
	meta.modified=FileAccess.get_modified_time(path)
	meta.thumbnail=path.get_basename()+".png"
	meta.damaged=not data.has("lots") or data.get("version",999)>Sim.SAVE_VERSION
	return meta

func list_saves() -> Array:
	var result:Array=[]
	for name in DirAccess.get_files_at(directory):
		if name.ends_with(".json"): result.append(read_metadata(directory+"/"+name))
	if FileAccess.file_exists(legacy_path): result.append(read_metadata(legacy_path))
	result.sort_custom(func(a,b):return a.modified>b.modified)
	return result

func continue_path() -> String:
	last_error=""
	if not latest_path.is_empty() and FileAccess.file_exists(latest_path):
		var latest=read_metadata(latest_path)
		if not latest.get("damaged",true): return latest_path
		last_error="Your most recent save is damaged. Continue uses an earlier valid save; Load Game offers backup recovery."
	var candidates=list_saves()
	for item in candidates:
		if not item.damaged: return item.path
	return ""

func manual_path() -> String:
	var sequence=1
	while FileAccess.file_exists(directory+"/manual_%03d.json"%sequence): sequence+=1
	return directory+"/manual_%03d.json"%sequence

func save_slot(sim,path:String,title:String,view:Dictionary,thumbnail:Image=null) -> bool:
	last_error=""
	if not owns(path):
		last_error="This save is outside the game's save slots."
		return false
	# Backups are verified by Sim.load_game during recovery, not trusted as metadata.
	if FileAccess.file_exists(path):
		var validator=Sim.new()
		if validator.load_game(path):
			if DirAccess.copy_absolute(path,path+".bak")!=OK:
				last_error="Could not preserve the previous save. Try another slot."
				return false
	sim.view_state=view.duplicate(true)
	sim.save_metadata={"title":title.strip_edges().left(60),"saved_at":Time.get_datetime_string_from_system(),"kind":"autosave" if path.get_file().begins_with("auto_") else ("quicksave" if path.get_file()=="quick.json" else "manual")}
	if not sim.save_game(path):
		last_error="Could not write the save. Your previous save is still available."
		return false
	if thumbnail!=null:
		var copy=thumbnail.duplicate()
		copy.resize(384,216,Image.INTERPOLATE_LANCZOS)
		copy.save_png(path.get_basename()+".png")
	remember(path)
	return true

func autosave(sim,view:Dictionary,thumbnail:Image=null) -> bool:
	var path=directory+"/auto_%d.json"%auto_index
	if not save_slot(sim,path,"Autosave · "+sim.company_name,view,thumbnail): return false
	auto_index=(auto_index+1)%3
	remember(path)
	return true

func campaign_save(sim,view:Dictionary,thumbnail:Image=null) -> bool:
	return save_slot(sim,directory+"/campaign_"+sim.scenario_id+".json",sim.company_name+" · campaign",view,thumbnail)

func load_slot(sim,path:String,recover:bool=false) -> bool:
	last_error=""
	if not owns(path):
		last_error="Unknown save slot."
		return false
	var source=path+".bak" if recover else path
	if not sim.load_game(source):
		last_error=sim.last_error+(" A backup is available: choose Recover backup." if FileAccess.file_exists(path+".bak") else " Choose an earlier autosave.")
		return false
	remember(path)
	return true

func delete_slot(path:String) -> bool:
	if not owns(path) or path==legacy_path: return false
	for suffix in ["",".bak"]:
		if FileAccess.file_exists(path+suffix) and DirAccess.remove_absolute(path+suffix)!=OK: return false
	var image_path=path.get_basename()+".png"
	if FileAccess.file_exists(image_path): DirAccess.remove_absolute(image_path)
	return true

func owns(path:String) -> bool:
	return path==legacy_path or (path.get_base_dir()==directory and path.get_file().ends_with(".json") and not ".." in path)
