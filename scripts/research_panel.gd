extends RefCounted
const Research=preload("res://scripts/research.gd")
var board
var game
var live:Label
var personality:Label
var rows=[]
var campaigns=[]
var journal:Label

func _init(owner_board) -> void:
	board=owner_board;game=board.game

func section(parent:Node,title:String) -> VBoxContainer:
	var panel=PanelContainer.new()
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var style=game.style(Color("1d3833"))
	style.content_margin_top=16;style.content_margin_bottom=16
	style.border_width_left=4;style.border_color=Color("3c6b5a");style.content_margin_left=18
	panel.add_theme_stylebox_override("panel",style);parent.add_child(panel)
	var box=VBoxContainer.new();box.add_theme_constant_override("separation",12);panel.add_child(box)
	copy(box,title,21,game.MINT)
	return box

func copy(parent:Node,text:String,size:int=16,color:Color=Color("e8e4d2")) -> Label:
	var label=Label.new();label.text=text;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label.set_meta("base_font_size",size);label.add_theme_font_size_override("font_size",roundi(size*game.settings.ui_scale))
	label.add_theme_color_override("font_color",color);parent.add_child(label);return label

func action(parent:Node,text:String,callback:Callable) -> Button:
	var button=game.button(parent,text,Rect2(0,0,200,40),callback)
	button.custom_minimum_size=Vector2(200,40);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	return button

func draw(parent:Node) -> void:
	var sim=game.sim
	var box=section(parent,"Feed the AI / shared campus capacity")
	personality=copy(box,"")
	copy(box,"Research draws physical compute BEFORE paying customers. A larger share can delay projects or break service promises. Switching projects keeps progress; completed projects automatically release their capacity.")
	live=copy(box,"")
	var controls=HBoxContainer.new();controls.add_theme_constant_override("separation",10);box.add_child(controls)
	for share in [0,10,25,50]:
		action(controls,"Pause research" if share==0 else "%d%% of online compute" % share,func():review_share(share))
	for id in Research.PROJECTS:
		var p:Dictionary=Research.PROJECTS[id]
		box=section(parent,p.branch+" / "+p.name)
		copy(box,p.brief)
		var status=copy(box,"")
		var button=action(box,"Select project",func():game.complete_action(Research.select(sim,id),"Research selected. Choose its compute share above.");board.refresh())
		rows.append({"id":id,"status":status,"button":button})
	box=section(parent,"AI open days / demand with responsibility")
	copy(box,"Each district campaign costs $1,200 and lasts 48h. Adoption rises toward a target 15 points higher, and spot demand grows by 15 compute. That demand needs capacity left AFTER research and contracts: unserved invitations add local reliability complaints. A campaign does not expand your infrastructure or guarantee profit.")
	for ward in sim.Geography.DISTRICTS:
		var status=copy(box,"")
		var button=action(box,"Invite "+sim.Geography.DISTRICTS[ward].name,func():game.ask("Host an AI open day?","Spend $1,200 for a 48h campaign in "+sim.Geography.DISTRICTS[ward].name+". Reserve 15 spare compute for its new demand or expect reliability complaints.",func():game.complete_action(Research.campaign(sim,ward),"AI open day started.");board.refresh()))
		campaigns.append({"ward":ward,"status":status,"button":button})
	box=section(parent,"Companion journal / observations from your town")
	journal=copy(box,"")
	update_live()

func review_share(share:int) -> void:
	var sim=game.sim
	var before=sim.metrics()
	var previous:int=sim.research.allocation
	sim.research.allocation=share
	var after=sim.metrics()
	sim.research.allocation=previous
	var warning=""
	for c in sim.active:
		if after.deliveries[c.id]<before.deliveries[c.id]-0.001: warning+="\n"+c.name+": %.1f → %.1f work/h" % [before.deliveries[c.id],after.deliveries[c.id]]
	game.ask("Allocate %d%% to research?" % share,"Research %.1f → %.1f compute/h.\nCampus cash flow %s → %s per hour.\nThe share applies to the next selected project too.%s" % [before.research_compute,after.research_compute,game.money_detail(before.profit),game.money_detail(after.profit),"\nCustomer delivery falls:"+warning if warning!="" else "\nNo current customer delivery reduction."],func():game.complete_action(Research.allocate(sim,share),"Research allocation updated.");board.refresh())

func update_live() -> void:
	var sim=game.sim;var state:Dictionary=sim.research;var m=sim.metrics()
	personality.text="Companion outlook: %s · %d / 6 discoveries" % [Research.personality(sim),state.completed.size()]
	var id:String=state.project
	live.text="Allocation %d%% · Research %.1f compute/h · Customers reserved %.0f · Free %.1f · Net %s/h\n%s" % [state.allocation,m.research_compute,m.reserved,m.free,game.money_detail(m.profit),"Select a project below." if id=="" else Research.PROJECTS[id].name+" — "+("paused / no online research capacity" if m.research_compute<=0 else "estimated %dh remaining" % ceili((Research.PROJECTS[id].work-state.progress.get(id,0))/m.research_compute))]
	for row in rows:
		var p:Dictionary=Research.PROJECTS[row.id]
		var reason=Research.reason(sim,row.id)
		row.status.text="%.0f / %d compute-hours · %s" % [state.progress.get(row.id,0),p.work,reason if reason!="" else ("Selected" if id==row.id else "Ready to research")]
		row.button.text="Completed" if Research.has(sim,row.id) else ("Selected" if id==row.id else "Select project")
		row.button.disabled=reason!="" or id==row.id
		row.button.tooltip_text=reason
	for row in campaigns:
		var reason=Research.campaign(sim,row.ward,true)
		var remaining=maxi(0,int(state.campaigns.get(row.ward,0))-sim.hour)
		row.status.text=sim.Geography.DISTRICTS[row.ward].name+" · "+("%dh remaining" % remaining if remaining>0 else (reason if reason!="" else "$1,200 · 48h · 15 extra compute demand"))
		row.button.disabled=reason!="";row.button.tooltip_text=reason
	journal.text="I am ready to learn. First, a working campus; then decide how much of it I may borrow."
	if not state.comments.is_empty():
		var lines=PackedStringArray()
		for entry in state.comments: lines.append("Day %d, %02d:00 — %s" % [int(entry.hour/24)+1,int(entry.hour)%24,entry.message])
		journal.text="\n\n".join(lines)
