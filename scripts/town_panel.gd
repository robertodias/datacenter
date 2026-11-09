extends RefCounted
const Civic=preload("res://scripts/civic.gd")
const Geo=preload("res://scripts/town_rules.gd")
var board
var game
var summary:Label
var concerns:Label
var demand:Label
var adoption_bar:ProgressBar
var opinion_bar:ProgressBar
var source=-1
var target=-1
var project=-1
var preserve=-1
var relocation:Label
var action_buttons:Array=[]
var move_button:Button

func _init(owner_board) -> void:
	board=owner_board;game=board.game

func meter(parent:Node,at:Vector2,color:Color) -> ProgressBar:
	var bar=ProgressBar.new();bar.position=at;bar.size=Vector2(440,16);bar.show_percentage=false
	bar.add_theme_stylebox_override("background",game.style(Color("102b29")))
	bar.add_theme_stylebox_override("fill",game.style(color));parent.add_child(bar)
	return bar

func picker(parent:Node,rect:Rect2,items:Array,callback:Callable,preferred:int=-1) -> void:
	var select=OptionButton.new();select.position=rect.position;select.size=rect.size;parent.add_child(select)
	var chosen=0
	for i in range(items.size()):
		select.add_item(items[i].name);select.set_item_metadata(i,items[i].id)
		if items[i].id==preferred: chosen=i
	if items.is_empty():
		select.add_item("No suitable parcels");select.disabled=true;callback.call(-1)
	else:
		select.select(chosen);callback.call(items[chosen].id)
	select.item_selected.connect(func(i):callback.call(select.get_item_metadata(i)))
	select.tooltip_text="Select a property. Parcel coordinates match the map inspector."

func draw(parent:Node) -> void:
	var sim=game.sim;var id=board.ward
	var p=board.card(parent,240)
	game.label(p,"Town council / support and adoption",Rect2(20,10,710,30),22)
	var select=OptionButton.new();select.position=Vector2(650,12);select.size=Vector2(315,35);p.add_child(select)
	var ids=Geo.DISTRICTS.keys()
	for key in ids: select.add_item(Geo.DISTRICTS[key].name)
	select.select(ids.find(id));select.item_selected.connect(func(i):board.ward=ids[i];board.refresh())
	summary=game.paragraph(p,"",Rect2(20,55,930,62),15,game.INK)
	game.label(p,"NEIGHBORHOOD APPROVAL",Rect2(20,126,440,23),12,game.MINT)
	game.label(p,"AI ADOPTION / LOCAL DEMAND",Rect2(510,126,440,23),12,game.GOLD)
	opinion_bar=meter(p,Vector2(20,158),game.MINT);adoption_bar=meter(p,Vector2(510,158),game.GOLD)
	game.paragraph(p,"Approval reflects living conditions. Adoption grows with useful deliveries and skills programs; it increases open-market demand. A customer can use AI and oppose your campus.",Rect2(20,190,930,44),12)
	p=board.card(parent,365)
	game.label(p,"Why this neighborhood is responding",Rect2(20,10,930,30),22)
	concerns=game.paragraph(p,"",Rect2(20,52,930,118),15,game.INK)
	demand=game.paragraph(p,"",Rect2(20,179,930,171),14,game.GOLD)
	p=board.card(parent,205)
	game.label(p,"Meet residents or expedite expansion",Rect2(20,10,930,29),22)
	game.paragraph(p,"Negotiation buys 24h to reduce the leading concern to the agreed target. Kept promises restore trust; broken promises worsen it. Meetings have a 48h cooldown. Permit pauses still apply. Expediting permits new halls and hall upgrades for 24h, at a lasting trust cost.",Rect2(20,50,930,78),14)
	game.button(p,"Negotiate · $600",Rect2(20,143,440,40),func():perform("negotiate","Promise to reduce %s from %.1f to %.1f within 24h. Escalation pauses during the meeting agreement. Missing this target adds 10 grievance and 4 stress." % [Civic.CAUSES[sim.civic_reports[id].primary],sim.civic_reports[id].concerns[sim.civic_reports[id].primary],maxf(8,sim.civic_reports[id].concerns[sim.civic_reports[id].primary]*0.65)]))
	game.button(p,"Expedite · $2,500",Rect2(480,143,485,40),func():perform("expedite","Allow hall expansion here for 24h despite a permit pause. Public standing -8, local grievance +12 and stress +4. Concerns and heritage protections remain."))
	p=board.card(parent,275)
	game.label(p,"Reduce the impact of operating buildings",Rect2(20,10,930,29),22)
	var equipment=[];var destinations=[];var plots=[];var landmarks=[]
	for i in range(sim.lots.size()):
		var lot:Dictionary=sim.lots[i];var local=Geo.district(lot.x,lot.y)==id
		var item={"id":i,"name":"%02d-%02d / %s" % [lot.x+1,lot.y+1,sim.BUILDINGS[lot.kind].name if lot.kind in sim.BUILDINGS else lot.kind.capitalize()]}
		if lot.kind in sim.BUILDINGS: equipment.append(item)
		if lot.owned and lot.kind=="grass": destinations.append(item)
		if local and lot.kind=="grass": plots.append(item)
		if local and lot.kind in ["park","monument"] and not lot.get("preserved",false): landmarks.append(item)
	game.label(p,"Source building (includes neighboring districts)",Rect2(20,51,600,23),13)
	picker(p,Rect2(20,80,600,38),equipment,func(value):source=value;update_live(),game.selected)
	game.button(p,"Acoustic barrier · $900",Rect2(650,80,315,38),func():perform("quiet","Reduce this site's noise contribution by 60%. Barriers stay at this site and do not move with equipment.",source))
	game.label(p,"Move selected hall to an owned vacant parcel",Rect2(20,132,600,23),13)
	picker(p,Rect2(20,161,600,38),destinations,func(value):target=value;update_live())
	move_button=game.button(p,"Review relocation",Rect2(650,161,315,38),func():review_move())
	relocation=game.paragraph(p,"",Rect2(20,214,930,51),13)
	p=board.card(parent,235)
	game.label(p,"Invest in the pressure you actually create",Rect2(20,10,930,30),22)
	game.paragraph(p,"Routing adds 10 trips/h of local street capacity. Grid and water projects raise town comfort budgets by 120 MW and 50 water units/h. These ease civic strain; operating capacity still requires substations and cooling plants. Skills programs increase adoption, not noise tolerance.",Rect2(20,50,930,78),14)
	game.button(p,"Routing · $1,600",Rect2(20,143,440,35),func():perform("traffic","Add 10 trips/h of routing capacity in this district."))
	game.button(p,"Grid works · $2,200",Rect2(480,143,485,35),func():perform("grid","Raise the town-wide electricity comfort budget by 120 MW. Substation output is unchanged."))
	game.button(p,"Water recycling · $1,800",Rect2(20,189,440,35),func():perform("water","Raise the town-wide water comfort budget by 50 units/h. Efficient hardware and closed-loop cooling also reduce water use."))
	game.button(p,"Skills program · $1,000",Rect2(480,189,485,35),func():perform("education","Add two local jobs and raise this district's long-term AI adoption target by 12 points. Maximum three programs."))
	p=board.card(parent,288)
	game.label(p,"Build homes, green space and replacement landmarks",Rect2(20,10,930,30),22)
	game.paragraph(p,"Choose a vacant parcel in this district. A funded home rehouses one displaced family or welcomes new workers. Parks restore removed green space. Replacement monuments address lost heritage. You keep any land you already own.",Rect2(20,50,930,59),14)
	picker(p,Rect2(20,124,600,38),plots,func(value):project=value,game.selected)
	game.button(p,"Locate parcel",Rect2(650,124,315,38),func():locate(project))
	game.button(p,"Home · $1,800",Rect2(20,180,290,38),func():perform("housing","Build a visible house at the chosen parcel; rehouse one displaced family if any remain.",project))
	game.button(p,"Park · $1,000",Rect2(335,180,290,38),func():perform("park","Create a visible park at the chosen parcel. It restores one removed green space.",project))
	game.button(p,"Memorial · $2,500",Rect2(650,180,315,38),func():perform("memorial","Create a protected replacement landmark and restore one lost monument.",project))
	game.paragraph(p,"Construction uses the selected parcel, including owned land. Public projects on unowned parcels stay public. Homes can later be purchased, but clearing them displaces families again.",Rect2(20,235,930,43),13)
	p=board.card(parent,160)
	game.label(p,"Preserve a landmark or park",Rect2(20,10,930,29),22)
	game.paragraph(p,"A permanent conservation covenant prevents future demolition and improves standing by 2. It survives a heritage hearing or expedited permit.",Rect2(20,49,930,46),14)
	picker(p,Rect2(20,107,600,38),landmarks,func(value):preserve=value,game.selected)
	game.button(p,"Preserve · $700",Rect2(650,107,315,38),func():perform("preserve","Permanently protect this site from demolition. Public standing +2. This covenant cannot be reversed.",preserve))
	if not sim.civic.history.is_empty():
		p=board.card(parent,55+mini(10,sim.civic.history.size())*45)
		game.label(p,"Council record / latest first",Rect2(20,10,930,28),20)
		for i in range(mini(10,sim.civic.history.size())):
			var row:Dictionary=sim.civic.history[i]
			game.paragraph(p,"Day %d %02d:00 / %s / %s" % [int(row.hour/24)+1,int(row.hour)%24,Geo.DISTRICTS[row.ward].name,row.message],Rect2(20,51+i*45,930,42),13)
	var prefixes={"Negotiate":"negotiate","Expedite":"expedite","Acoustic":"quiet","Routing":"traffic","Grid works":"grid","Water recycling":"water","Skills program":"education","Home ·":"housing","Park ·":"park","Memorial":"memorial","Preserve ·":"preserve"}
	for child in parent.find_children("*","Button",true,false):
		for prefix in prefixes:
			if child.text.begins_with(prefix): action_buttons.append({"button":child,"action":prefixes[prefix]})
	update_live()

func locate(index:int) -> void:
	if index<0: return
	board.visible=false;game.focus_lot(index)

func perform(action:String,detail:String,index:int=-1) -> void:
	var id=board.ward
	game.ask(action.capitalize()+" / "+Geo.DISTRICTS[id].name,"Cost: "+game.money(Civic.COSTS[action])+".\n\n"+detail,func():game.complete_action(game.sim.council(action,id,index),"Council action completed. Check the cause and recovery timer."))

func review_move() -> void:
	var sim=game.sim
	if source<0 or target<0: game.toast("Choose a hall and an owned vacant destination.");return
	var from=source;var to=target;var p=sim.site_preview(to)
	game.ask("Relocate server hall?","Cost %s including road access. Keeps tier, hardware and condition. Hall stops for 2h. Source becomes vacant; barriers stay behind.\n\nDestination: %s.\nPower %s / Cooling %s.\n%s" % [game.money(1500+Geo.connection_cost(sim.lots[to])),Geo.DISTRICTS[Civic.ward_for(sim.lots[to])].name,"in reach" if p.power else "MISSING","in reach" if p.cooling else "MISSING",p.permit_error],func():game.complete_action(sim.relocate_hall(from,to),"Hall relocated. Two-hour commissioning started."))

func update_live() -> void:
	if summary==null or not is_instance_valid(summary): return
	var sim=game.sim;var id=board.ward;var w:Dictionary=sim.civic.wards[id];var r:Dictionary=sim.civic_reports[id]
	summary.text="%s / %s / pressure %.1f / stress %.0f\nApproval %.0f%% · AI adoption %.0f%% · %d residents · %d jobs · Market demand %.0f compute/h town-wide" % [Geo.DISTRICTS[id].name,Civic.STAGES[int(w.stage)],r.pressure,w.stress,w.opinion,w.adoption,r.population,r.jobs,sim.metrics().spot_limit]
	opinion_bar.value=w.opinion;adoption_bar.value=w.adoption
	concerns.text="Displaced families %d (%.1f) · Noise %.1f (%.1f) · Trips %.1f / %d (%.1f)\nTown grid %.1f / %d MW (%.1f) · Water %.1f / %d (%.1f)\nLost parks %d / landmarks %d (%.1f) · Service disruption %.1f · Distrust %.1f\nJobs / preservation offset %.1f pressure. Values in brackets are concern points." % [w.displaced,r.concerns.displacement,r.noise,r.concerns.noise,r.trips,12+w.traffic_projects*10,r.concerns.traffic,sim.civic.grid_draw,220+sim.civic.grid_projects*120,r.concerns.power,sim.civic.water_use,70+sim.civic.water_projects*50,r.concerns.water,w.green_loss,w.heritage_loss,r.concerns.heritage,r.concerns.reliability,r.concerns.trust,r.benefit]
	demand.text="Demand: %s.\nStress rises at pressure >=18; falls 2/h below 12. Warning 4 / petition 10 / demonstration 18 / permit pause 28. Pauses restrict new halls and hall upgrades; repairs, utilities, refits and remedies stay available." % (Civic.CAUSES[r.primary] if r.pressure>=8 else "Keep impacts low and services reliable")
	if w.ceasefire_until>sim.hour: demand.text+="\nPromise: %s <=%.1f in %dh." % [w.promise_cause,w.promise_value,w.ceasefire_until-sim.hour]
	if w.waiver_until>sim.hour: demand.text+="\nExpedited permit: %dh left." % (w.waiver_until-sim.hour)
	if relocation!=null:
		relocation.text="Moving away from homes reduces real noise exposure. All source buildings are listed because noise crosses district boundaries."

	for row in action_buttons:
		var index=source if row.action=="quiet" else (project if row.action in ["housing","park","memorial"] else (preserve if row.action=="preserve" else -1))
		var error=Civic.act(sim,row.action,id,index,true)
		row.button.disabled=not error.is_empty()
		row.button.tooltip_text=error if error!="" else row.button.text+" / Review cost and consequences before applying."
	if move_button!=null:
		var error=sim.relocate_hall(source,target,true)
		move_button.disabled=not error.is_empty();move_button.tooltip_text=error if error!="" else "Review relocation cost, downtime and destination utilities."
