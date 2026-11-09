extends Control
## Front door and pause hub. Save, Load and destructive actions have separate flows.
var game
var body:Panel
var mode="title"
var return_mode="title"
var title_label:Label
var rebinding=""
var feedback:Label
var company_edit:LineEdit
var scenario_choice:OptionButton
var difficulty_choice:OptionButton
var save_name:LineEdit
var save_list:VBoxContainer
var loading_bar:ProgressBar
var selected_save=""
var splash_art:TextureRect
var brand_shade:TextureRect
var shade:ColorRect

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	splash_art=TextureRect.new()
	splash_art.texture=preload("res://assets/branding/hyperscale-splash.png")
	splash_art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	splash_art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	splash_art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	splash_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(splash_art)
	brand_shade=TextureRect.new()
	var gradient=Gradient.new()
	gradient.colors=PackedColorArray([Color(0.025,0.07,0.065,0.88),Color(0.025,0.07,0.065,0.12)])
	var gradient_texture=GradientTexture2D.new();gradient_texture.gradient=gradient
	gradient_texture.fill_from=Vector2(0,0.5);gradient_texture.fill_to=Vector2(1,0.5)
	brand_shade.texture=gradient_texture;brand_shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	brand_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(brand_shade)
	shade=ColorRect.new()
	shade.color=Color(0.025,0.07,0.065,0.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	body=game.panel(self,Rect2(0,0,1120,730),Color("142c2b"))
	visible=false

func fit() -> void:
	size=game.stage.size
	body.position=(size-body.size)/2

func open(section:String) -> void:
	get_parent().move_child(self,get_parent().get_child_count()-1)
	if game.map_tools!=null: game.map_tools.visible=false
	if section in ["settings","load","save","credits"] and mode not in [section,"loading"]: return_mode=mode
	mode=section
	visible=true
	rebinding=""
	refresh()

func close() -> void:
	if game.session_started:
		visible=false
	else: open("title")

func back() -> void:
	if mode=="loading": return
	if mode in ["title","pause"]: close()
	else: open("pause" if game.session_started else "title")

func refresh() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	fit()
	var branded=mode in ["title","loading"]
	splash_art.visible=branded;brand_shade.visible=branded;shade.visible=not branded
	body.add_theme_stylebox_override("panel",StyleBoxEmpty.new() if branded else game.style(Color("142c2b")))
	if mode=="title":
		feedback=game.paragraph(body,"",Rect2(40,678,1020,32),14,game.GOLD)
		title_home();call_deferred("focus_first");return
	if mode=="loading":
		brand_logo(Rect2(170,105,780,260))
		game.panel(body,Rect2(160,395,800,195),Color(0.05,0.13,0.12,0.95))
		game.label(body,"PREPARING YOUR TOWN",Rect2(230,420,660,28),18,game.MINT)
		loading_bar=ProgressBar.new();loading_bar.position=Vector2(230,467);loading_bar.size=Vector2(660,24);body.add_child(loading_bar)
		feedback=game.paragraph(body,"",Rect2(230,516,660,57),16,game.INK)
		return
	brand_logo(Rect2(22,8,200,66))
	game.label(body,{"title":"YOUR TOWN HAD HISTORY. NOW IT HAS CAPACITY.","pause":"COMPANY MENU · SIMULATION PAUSED","new":"ESTABLISH YOUR COMPANY","load":"LOAD A TOWN","save":"SAVE YOUR TOWN","settings":"SETTINGS","credits":"CREDITS","loading":"PREPARING YOUR TOWN","unsaved":"PROTECT YOUR PROGRESS"}.get(mode,mode.to_upper()),Rect2(32,73,950,27),13,game.MINT)
	if mode not in ["title","loading","unsaved"]: game.button(body,"Back · Esc",Rect2(940,27,150,38),back)
	feedback=game.paragraph(body,"",Rect2(32,666,1050,44),14,game.GOLD)
	match mode:
		"title","pause": home()
		"new": new_company()
		"load","save": slots()
		"settings": settings()
		"credits": credits()
		"loading":
			loading_bar=ProgressBar.new()
			loading_bar.position=Vector2(50,320)
			loading_bar.size=Vector2(1020,28)
			body.add_child(loading_bar)
			game.paragraph(body,"Tip: leave spare power and cooling capacity before signing a critical customer.",Rect2(50,390,1000,60),18)
		"unsaved": unsaved()
	call_deferred("focus_first")

func brand_logo(rect:Rect2) -> TextureRect:
	var logo=TextureRect.new();logo.name="BrandLogo"
	logo.texture=preload("res://assets/branding/hyperscale-logo.png")
	logo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;logo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter=Control.MOUSE_FILTER_IGNORE;logo.position=rect.position;logo.size=rect.size
	logo.tooltip_text="Hyperscale: Datacenter Tycoon";body.add_child(logo);return logo

func title_home() -> void:
	brand_logo(Rect2(25,24,750,250))
	game.label(body,"YOUR TOWN HAD HISTORY. NOW IT HAS CAPACITY.",Rect2(40,286,800,26),14,game.MINT)
	var latest=game.saves.continue_path()
	if not game.saves.last_error.is_empty(): feedback.text=game.saves.last_error
	var items=[
		["Continue",func():game.load_town(latest)],
		["New Company",func():game.request_leave(func():open("new"))],
		["Load Game",func():open("load")],
		["Settings",func():open("settings")],
		["Credits",func():open("credits")],
		["Quit",func():game.request_leave(func():game.get_tree().quit())]]
	for i in range(items.size()):
		var b=game.button(body,items[i][0],Rect2(40,335+i*53,290,44),items[i][1],i==0)
		if i==0: b.disabled=latest.is_empty()
	var preview=game.panel(body,Rect2(580,499,500,153),Color(0.05,0.13,0.12,0.94))
	if latest.is_empty():
		game.label(preview,"A town full of potential",Rect2(22,15,456,30),23)
		game.paragraph(preview,"Build a campus. Win AI customers. Keep the lights on. Give the town a future worth living in.",Rect2(22,58,456,67),17)
	else:
		var meta=game.saves.read_metadata(latest)
		game.label(preview,"CONTINUE YOUR COMPANY",Rect2(22,13,456,23),12,game.MINT)
		game.label(preview,meta.get("company","Your company"),Rect2(22,44,456,33),23)
		game.label(preview,"%s · Day %d · %s" % [meta.get("scenario","littlebrook").capitalize(),meta.get("day",1),game.money(meta.get("cash",0))],Rect2(22,93,456,26),16)
	game.label(body,"Tab / Shift+Tab navigate · Enter selects · F11 toggles fullscreen",Rect2(580,671,500,24),12,game.MINT)

func focus_first() -> void:
	if not visible or mode=="loading": return
	var buttons=body.find_children("*","Button",true,false)
	for b in buttons:
		if not b.disabled:
			b.grab_focus()
			return

func home() -> void:
	var playing=mode=="pause" and game.session_started
	var latest=game.saves.continue_path()
	if not game.saves.last_error.is_empty(): feedback.text=game.saves.last_error
	var items=[]
	if playing: items.append(["Resume town",func():close()])
	else: items.append(["Continue",func():game.load_town(latest)])
	items.append(["New Company",func():game.request_leave(func():open("new"))])
	if playing: items.append(["Save Game",func():open("save")])
	items.append(["Load Game",func():open("load")])
	items.append(["Settings",func():open("settings")])
	items.append(["Credits",func():open("credits")])
	if playing: items.append(["Return to title",func():game.request_leave(game.return_to_title)])
	items.append(["Quit",func():game.request_leave(func():game.get_tree().quit())])
	var y=135
	for i in range(items.size()):
		var b=game.button(body,items[i][0],Rect2(32,y,290,48),items[i][1],i==0)
		if i==0 and not playing: b.disabled=latest.is_empty()
		y+=60
	var preview=game.panel(body,Rect2(352,135,738,465),Color("203b34"))
	if not latest.is_empty():
		var meta=game.saves.read_metadata(latest)
		show_thumbnail(preview,meta,Rect2(16,16,706,265))
		game.label(preview,meta.get("company","Your company"),Rect2(20,295,695,34),25)
		game.label(preview,"%s · Day %d · %s"%[meta.get("scenario","littlebrook").capitalize(),meta.get("day",1),game.money(meta.get("cash",0))],Rect2(20,341,690,29),17,game.MINT)
		game.label(preview,"Last played: "+meta.get("saved_at",Time.get_datetime_string_from_unix_time(meta.get("modified",0))).replace("T"," "),Rect2(20,380,690,25),14)
		game.label(preview,"%d deliveries · %s played"%[meta.get("deliveries",0),playtime(meta.get("play_seconds",0))],Rect2(20,415,690,24),14)
	else:
		game.label(preview,"A town full of potential",Rect2(35,100,650,44),32)
		game.paragraph(preview,"Build server campuses, attract AI customers, keep the infrastructure running, and decide what Littlebrook's future should look like.",Rect2(35,170,650,120),22)
		game.label(preview,"Start with New Company",Rect2(35,340,650,35),20,game.MINT)
	game.label(body,"Tab / Shift+Tab navigate · Enter selects · F11 toggles fullscreen",Rect2(354,618,735,28),14,game.MUTED)

func new_company() -> void:
	game.label(body,"Company name",Rect2(32,135,400,26),18)
	company_edit=LineEdit.new()
	company_edit.text="Littlebrook Infrastructure Co."
	company_edit.max_length=48
	company_edit.position=Vector2(32,174)
	company_edit.size=Vector2(510,44)
	body.add_child(company_edit)
	game.label(body,"Scenario",Rect2(32,246,400,26),18)
	scenario_choice=OptionButton.new()
	scenario_choice.add_item("Littlebrook · First campus campaign")
	scenario_choice.add_item("Littlebrook · Sandbox · $1,000,000 start")
	scenario_choice.add_item("Sunsprawl · Heat, water and resilience")
	scenario_choice.add_item("Oldbridge · Heritage and public trust")
	scenario_choice.position=Vector2(32,284)
	scenario_choice.size=Vector2(510,44)
	body.add_child(scenario_choice)
	game.label(body,"Challenge",Rect2(32,355,400,26),18)
	difficulty_choice=OptionButton.new()
	for choice in ["Relaxed · $28,000 start · gentler pressure","Standard · $22,000 start · recommended","Challenging · $18,000 start · tighter finances"]: difficulty_choice.add_item(choice)
	difficulty_choice.select(1)
	difficulty_choice.position=Vector2(32,394)
	difficulty_choice.size=Vector2(510,44)
	body.add_child(difficulty_choice)
	var guide=CheckButton.new();guide.text="Guided introduction (can be skipped anytime)";guide.button_pressed=true
	guide.position=Vector2(32,450);guide.size=Vector2(510,40);body.add_child(guide)
	var brief=game.panel(body,Rect2(575,135,515,430),Color("203b34"))
	var town_title=game.label(brief,"",Rect2(24,22,470,37),29)
	var town_brief=game.paragraph(brief,"",Rect2(24,80,465,162),18)
	var town_goal=game.paragraph(brief,"",Rect2(24,260,465,150),16)
	var choices=["littlebrook","sandbox","sunsprawl","oldbridge"]
	var update_brief=func():
		var info:Dictionary=game.sim.Scenarios.info(choices[scenario_choice.selected])
		town_title.text=info.name.to_upper();town_brief.text=info.brief;town_goal.text=info.goal
	scenario_choice.item_selected.connect(func(_i):update_brief.call())
	update_brief.call()
	game.button(body,"Establish company",Rect2(32,505,510,55),func():
		var name=company_edit.text.strip_edges()
		if name.is_empty(): feedback.text="Enter a company name first.";return
		game.start_company(name,choices[scenario_choice.selected],["relaxed","standard","challenging"][difficulty_choice.selected],guide.button_pressed),true)

func slots() -> void:
	var y=130
	if mode=="save":
		game.label(body,"Save name",Rect2(32,127,150,27),16)
		save_name=LineEdit.new()
		save_name.text=game.sim.company_name+" · Day %d"%(game.sim.hour/24+1)
		save_name.max_length=60
		save_name.position=Vector2(185,124)
		save_name.size=Vector2(605,40)
		body.add_child(save_name)
		game.button(body,"Create new save",Rect2(807,124,280,40),func():write_slot(game.saves.manual_path(),false),true)
		y=180
	var scroll=ScrollContainer.new()
	scroll.position=Vector2(32,y)
	scroll.size=Vector2(1058,640-y)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	save_list=VBoxContainer.new()
	save_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	save_list.add_theme_constant_override("separation",12)
	scroll.add_child(save_list)
	var all=game.saves.list_saves()
	if all.is_empty():
		var empty=game.paragraph(save_list,"No saved towns yet. Start a new company to begin.",Rect2(0,0,1000,80),20)
		empty.custom_minimum_size=Vector2(1000,80)
	for meta in all: slot_card(meta)

func slot_card(meta:Dictionary) -> void:
	var row=game.panel(save_list,Rect2(0,0,1030,167),Color("203b34"))
	row.custom_minimum_size=Vector2(1030,167)
	row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	show_thumbnail(row,meta,Rect2(12,12,220,124))
	game.label(row,meta.title,Rect2(250,9,560,32),21)
	var details="Damaged or unsupported save. Try its backup or an earlier autosave." if meta.damaged else "%s · Day %d · %s · %s played"%[meta.get("scenario","littlebrook").capitalize(),meta.get("day",1),game.money(meta.get("cash",0)),playtime(meta.get("play_seconds",0))]
	game.paragraph(row,details,Rect2(250,51,550,52),14,game.GOLD if meta.damaged else game.INK)
	game.label(row,meta.get("saved_at",Time.get_datetime_string_from_unix_time(meta.modified)).replace("T"," "),Rect2(250,111,550,24),13,game.MUTED)
	if mode=="load":
		var b=game.button(row,"Load town",Rect2(817,15,195,39),func():game.request_leave(func():game.load_town(meta.path)),true)
		b.disabled=meta.damaged
	else:
		var overwrite=game.button(row,"Overwrite",Rect2(817,15,195,39),func():write_slot(meta.path,true))
		overwrite.disabled=meta.path==game.saves.legacy_path
	var recover=game.button(row,"Recover backup",Rect2(817,65,195,37),func():game.request_leave(func():game.load_town(meta.path,true)))
	recover.disabled=not FileAccess.file_exists(meta.path+".bak")
	var delete=game.button(row,"Delete save",Rect2(817,115,195,35),func():game.ask("Delete this save?","Delete '"+meta.title+"' and its backup? Other saves are kept.",func():
		if not game.saves.delete_slot(meta.path): feedback.text="Could not delete this save."
		else: refresh()))
	delete.disabled=meta.path==game.saves.legacy_path

func write_slot(path:String,overwrite:bool) -> void:
	var title=save_name.text.strip_edges()
	if title.is_empty(): feedback.text="Enter a name for this save.";return
	var action=func():
		if game.save_to(path,title): refresh();feedback.text="Town saved."
		else: feedback.text=game.saves.last_error
	if overwrite: game.ask("Overwrite save?","Replace this saved town? The previous good file will be kept as its backup.",action)
	else: action.call()

func show_thumbnail(parent:Node,meta:Dictionary,rect:Rect2) -> void:
	var texture=TextureRect.new()
	texture.position=rect.position
	texture.size=rect.size
	texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var path=meta.get("thumbnail","")
	if FileAccess.file_exists(path):
		var img=Image.load_from_file(path)
		if img!=null: texture.texture=ImageTexture.create_from_image(img)
	parent.add_child(texture)
	if texture.texture==null:
		var placeholder=game.panel(parent,rect,Color("365749"))
		game.label(placeholder,"LITTLEBROOK",Rect2(15,20,rect.size.x-25,30),18,game.MINT)

func settings() -> void:
	var cfg=game.settings
	var left=game.panel(body,Rect2(32,132,510,503),Color("203b34"))
	game.label(left,"Display & accessibility",Rect2(20,13,470,35),23)
	check(left,"Fullscreen · F11 / Alt+Enter",60,cfg.fullscreen,func(value):
		if value!=game.is_fullscreen(): game.toggle_fullscreen())
	game.label(left,"Window resolution",Rect2(20,110,220,27),16)
	var res=OptionButton.new()
	var sizes=[Vector2i(1152,720),Vector2i(1280,800),Vector2i(1440,900),Vector2i(1920,1080),Vector2i(2560,1440)]
	for r in sizes: res.add_item("%d × %d"%[r.x,r.y])
	res.select(maxi(0,sizes.find(cfg.resolution)))
	res.position=Vector2(255,108);res.size=Vector2(230,36)
	res.item_selected.connect(func(i):cfg.resolution=sizes[i];game.apply_settings(true))
	left.add_child(res)
	game.label(left,"Text size",Rect2(20,162,220,27),16)
	var scale=OptionButton.new()
	for caption in ["Compact · 85%","Standard · 100%","Large · 115%"]: scale.add_item(caption)
	scale.select(0 if cfg.ui_scale<0.95 else (2 if cfg.ui_scale>1.05 else 1))
	scale.position=Vector2(255,160);scale.size=Vector2(230,36)
	scale.item_selected.connect(func(i):cfg.ui_scale=[0.85,1.0,1.15][i];game.apply_settings())
	left.add_child(scale)
	check(left,"Reduced motion",215,cfg.reduced_motion,func(value):cfg.reduced_motion=value;game.apply_settings())
	check(left,"Pause on important warnings",265,cfg.auto_pause,func(value):cfg.auto_pause=value;game.apply_settings())
	check(left,"Master sound",305,cfg.sound,func(value):cfg.sound=value;game.apply_settings())
	game.label(left,"Sound volume",Rect2(20,349,220,27),16)
	var volume=HSlider.new()
	volume.position=Vector2(255,346);volume.size=Vector2(230,33)
	volume.min_value=0;volume.max_value=100;volume.value=cfg.volume*100
	volume.value_changed.connect(func(value):cfg.volume=value/100;game.apply_settings())
	left.add_child(volume)
	check(left,"Music / adaptive score",395,cfg.music,func(value):cfg.music=value;game.apply_settings())
	check(left,"Ambience / machinery / AI voice",444,cfg.ambience,func(value):cfg.ambience=value;game.apply_settings())
	var right=game.panel(body,Rect2(566,132,524,503),Color("203b34"))
	game.label(right,"Controls · select a key to rebind",Rect2(18,13,490,35),20)
	var y=63
	var names={"inspect":"Inspect","buy":"Buy land","demolish":"Bulldoze","datacenter":"Server hall","power":"Power","cooling":"Cooling","contracts":"Contracts","company":"Company","pause":"Pause / run","speed":"Simulation speed"}
	for action in cfg.bindings:
		game.label(right,names[action],Rect2(20,y,305,26),15)
		game.button(right,cfg.key_label(action),Rect2(345,y-3,155,32),func():rebinding=action;feedback.text="Press a new key for "+names[action]+". Escape cancels.")
		y+=39
	game.button(right,"Restore default controls",Rect2(20,457,480,34),func():cfg.bindings=cfg.DEFAULT_BINDINGS.duplicate();game.apply_settings();refresh())

func check(parent:Node,text:String,y:int,value:bool,action:Callable) -> void:
	var cb=CheckButton.new()
	cb.text=text
	cb.position=Vector2(15,y)
	cb.size=Vector2(485,35)
	cb.button_pressed=value
	cb.toggled.connect(action)
	parent.add_child(cb)

func capture_key(event:InputEventKey) -> bool:
	if rebinding.is_empty() or not event.pressed or event.echo: return false
	if event.keycode==KEY_ESCAPE: rebinding="";feedback.text="Rebinding cancelled.";return true
	var error=game.settings.bind_action(rebinding,event.keycode)
	if not error.is_empty(): feedback.text=error;return true
	rebinding=""
	game.apply_settings()
	refresh()
	feedback.text="Control updated and saved."
	return true

func credits() -> void:
	game.paragraph(body,"HYPERSCALE: DATACENTER TYCOON\n\nDesign and development: this project, built with Codex and Godot.\nOriginal code-drawn isometric artwork, synthesized music, ambience and action audio.
Brand icon, logo and title illustration created for this project (see assets/branding).\n\nGodot Engine is MIT licensed. Its license and third-party notices are distributed with the Windows executable.\n\nDesign inspirations: classic construction and management games, the delight of a working system, and the absurd appetite of AI for infrastructure.",Rect2(50,150,1000,400),21)

func unsaved() -> void:
	game.paragraph(body,"Your current town has changes since its last save. Save a campaign checkpoint before continuing, or discard only those unsaved changes.",Rect2(50,190,1000,120),25)
	game.button(body,"Save & continue",Rect2(50,400,315,55),func():
		if game.save_campaign(): game.run_leave_action()
		else: feedback.text=game.saves.last_error,true)
	game.button(body,"Discard unsaved changes",Rect2(395,400,315,55),game.run_leave_action)
	game.button(body,"Keep playing",Rect2(740,400,315,55),func():visible=false)

func loading(progress:float,message:String) -> void:
	if mode!="loading": open("loading")
	loading_bar.value=progress
	feedback.text=message

func playtime(seconds:float) -> String:
	var mins=int(seconds)/60
	return "%dh %02dm"%[mins/60,mins%60]
