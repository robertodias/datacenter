extends Control
const Mini=preload("res://scripts/minimap.gd")
const Geo=preload("res://scripts/town_rules.gd")
const LAYERS=["Town view","Electricity","Cooling","Noise","Ownership","Opinion"]
var game
var body:Panel
var bookmarks:Array=[]
var layer="Town view"
var layer_legend:Label
var time_summary:Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	visible=false

func fit() -> void:
	size=game.stage.size
	if body!=null: body.position=(size-body.size)/2

func open() -> void:
	get_parent().move_child(self,get_parent().get_child_count()-1)
	game.business.visible=false
	visible=true
	refresh()

func refresh() -> void:
	for child in get_children(): remove_child(child);child.queue_free()
	var shade=ColorRect.new()
	shade.color=Color(0.03,0.08,0.07,0.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	body=game.panel(self,Rect2(0,0,1120,730))
	fit()
	game.label(body,"LITTLEBROOK / TOWN ATLAS",Rect2(28,18,930,36),27)
	game.button(body,"Close · Esc",Rect2(960,19,130,36),func():visible=false).grab_focus()
	time_summary=game.paragraph(body,"256 parcels · Click the map or a building to inspect it. %s · Space toggles time." % ("Paused" if game.paused else "Running at %d×" % game.speed),Rect2(30,63,1040,38),15)
	var mini=Mini.new()
	mini.game=game;mini.position=Vector2(30,110);mini.size=Vector2(430,430)
	mini.focused.connect(focus_lot)
	body.add_child(mini)
	game.paragraph(body,"H hall · P power · C cooling\nBrown homes · Blue river · Pale protected sites\nGold polygon: visible camera area",Rect2(30,544,440,62),12)
	game.label(body,"MAP LAYER",Rect2(490,107,200,24),12,game.MUTED)
	var options=OptionButton.new()
	options.position=Vector2(490,139);options.size=Vector2(290,37)
	for name in LAYERS: options.add_item(name)
	options.selected=LAYERS.find(layer)
	options.item_selected.connect(func(i):set_layer(LAYERS[i]))
	body.add_child(options)
	game.button(body,"Show layer in town",Rect2(795,139,295,37),func():visible=false)
	layer_legend=game.paragraph(body,legend(),Rect2(490,185,600,62),14)
	game.label(body,"BUILDINGS / CLICK TO INSPECT",Rect2(490,255,290,24),13,game.MINT)
	var scroll=ScrollContainer.new()
	scroll.position=Vector2(490,287);scroll.size=Vector2(600,291)
	body.add_child(scroll)
	var rows=VBoxContainer.new()
	rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	var count=0
	for lot in game.sim.lots:
		if not game.sim.BUILDINGS.has(lot.kind): continue
		count+=1
		var row=Control.new();row.custom_minimum_size=Vector2(570,47);rows.add_child(row)
		var idx=game.sim.cell(int(lot.x),int(lot.y))
		var caption="%s T%d · %02d-%02d · %s" % [game.sim.BUILDINGS[lot.kind].name,lot.level,lot.x+1,lot.y+1,Geo.DISTRICTS[Geo.district(int(lot.x),int(lot.y))].name]
		game.button(row,caption,Rect2(0,0,570,41),func():focus_lot(idx))
	if count==0: game.label(rows,"No equipment yet. The old warehouse is at 04-06.",Rect2(0,0,580,40),14)
	game.label(body,"CAMERA BOOKMARKS / SAVED WITH THIS TOWN",Rect2(30,615,1050,23),12,game.MUTED)
	game.button(body,"+ Bookmark current view",Rect2(30,651,240,39),add_bookmark)
	for i in range(bookmarks.size()):
		var n=i
		game.button(body,bookmarks[i].name,Rect2(285+i*265,651,210,39),func():recall(n))
		game.button(body,"×",Rect2(500+i*265,651,34,39),func():bookmarks.remove_at(n);game.dirty=true;refresh()).tooltip_text="Remove bookmark: "+bookmarks[i].name
	game.button(body,"Old warehouse",Rect2(795,255,295,26),func():focus_lot(game.sim.cell(3,5)))

func set_layer(value:String) -> void:
	layer=value
	game.town.overlay=value
	game.dirty=true
	game.overlay_legend.text=legend()
	game.overlay_legend.visible=value!="Town view"
	if is_instance_valid(layer_legend): layer_legend.text=legend()
	game.overlay_choice.select(LAYERS.find(value))

func legend() -> String:
	match layer:
		"Electricity": return "P = within substation reach. Tier 1: 4 blocks · T2: 7 · T3: 12. Capacity is shared."
		"Cooling": return "C = within cooling reach. Riverfront coolers supply 25% more. Power still required."
		"Noise": return "Numbers show noise pressure, weighted by neighborhood sensitivity. Higher is worse."
		"Ownership": return "Y = your land · $ = available · ! = protected · — = public river / road."
		"Opinion": return "Local approval reflects jobs, displacement, resources, trust and noise. Town council explains each district."
	return "Scroll: zoom · Middle-drag: pan · Home: whole town · Map: bookmarks and building list"

func focus_lot(index:int) -> void:
	visible=false
	game.focus_lot(index)

func add_bookmark() -> void:
	if bookmarks.size()>=3: game.toast("Three bookmarks available. Remove one with × before adding another.");return
	var lot:Dictionary=game.sim.lots[maxi(0,game.selected)]
	bookmarks.append({"name":"%02d-%02d · %s" % [lot.x+1,lot.y+1,Geo.DISTRICTS[Geo.district(int(lot.x),int(lot.y))].name],"zoom":game.town.zoom,"pan_x":game.town.pan.x,"pan_y":game.town.pan.y,"selected":game.selected})
	game.dirty=true;refresh()

func recall(index:int) -> void:
	var b=bookmarks[index]
	game.town.zoom=float(b.zoom)
	game.town.pan=Vector2(b.pan_x,b.pan_y)
	game.on_selected(int(b.selected))
	game.town.update_camera()
	visible=false

func _process(_delta:float) -> void:
	if not visible: return
	fit()
	if is_instance_valid(time_summary):
		time_summary.text="256 parcels · Click the map or a building to inspect it. %s · Space toggles time." % ("Paused" if game.paused else "Running at %d×" % game.speed)
