extends Node
## Crossfaded original score and restrained environmental/AI sound layers.
var game
var layers:Dictionary={}
var current_mood="small_town"
var last_comment=""
var sample_timer=0.5
var targets:Dictionary={}
var voice:AudioStreamPlayer
func _exit_tree() -> void:
	for player in layers.values():
		player.stop()
		player.stream=null
	if is_instance_valid(voice):
		voice.stop()
		voice.stream=null
	layers.clear()

func _ready() -> void:
	for key in ["small_town","growing_company","under_pressure","town","machines","crowd"]:
		var player=AudioStreamPlayer.new()
		var stream=load("res://assets/audio/"+key+".wav").duplicate()
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_begin=0;stream.loop_end=stream.data.size()/2
		player.stream=stream;player.volume_db=-60;add_child(player);player.play();layers[key]=player
	voice=AudioStreamPlayer.new();voice.stream=load("res://assets/audio/ai_voice.wav");voice.volume_db=-18;add_child(voice)
func _process(delta:float) -> void:
	if game==null or game.sim==null: return
	sample_timer+=delta
	if sample_timer>=0.5:
		sample_timer=0;refresh_mix()
	for key in layers:
		var player:AudioStreamPlayer=layers[key]
		player.volume_linear=move_toward(player.volume_linear,targets.get(key,0.0),delta*0.18) if game.sound_enabled else 0.0
	if not game.sound_enabled: voice.stop()

func refresh_mix() -> void:
	var sim=game.sim
	var pressure=sim.ops.events.any(func(e):return e.phase=="active") or sim.civic.wards.values().any(func(w):return w.stage>=3)
	current_mood="under_pressure" if pressure else ("growing_company" if sim.campaign_count()>=2 else "small_town")
	var in_town=game.session_started and not game.menu.visible
	var moving=in_town and not game.paused
	for key in layers:
		var wanted=0.0
		if game.sound_enabled:
			if key in ["small_town","growing_company","under_pressure"] and game.settings.music and key==current_mood: wanted=0.3
			if game.settings.ambience and moving:
				if key=="town": wanted=0.25
				elif key=="machines" and sim.metrics().compute>0: wanted=0.22
				elif key=="crowd" and sim.civic.wards.values().any(func(w):return w.stage>=3): wanted=0.32
		targets[key]=wanted
	var comment="" if sim.research.comments.is_empty() else sim.research.comments[0].message
	if comment!=last_comment:
		if last_comment!="" and game.sound_enabled and game.settings.ambience and in_town: voice.play()
		last_comment=comment
	if not game.sound_enabled: voice.stop()
