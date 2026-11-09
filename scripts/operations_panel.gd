extends RefCounted
const Ops=preload("res://scripts/operations.gd")
var board
var game
var overview:Label
var reserves:Label
var equipment_heading:Control
var event_rows:Array=[]
var equipment_rows:Array=[]
var gear_label:Label
var warm_button:Button
var crews_button:Button
var fuel_button:Button
var rental_button:Button
var battery_button:Button
var generator_button:Button

func _init(owner_board) -> void:
	board=owner_board;game=board.game

func draw(parent:Node) -> void:
	var sim=game.sim
	var teams=board.card(parent,65)
	game.label(teams,"Specialist teams / dispatch priorities and wages",Rect2(20,16,710,30),19)
	game.button(teams,"Manage teams",Rect2(780,14,185,38),func():board.open("workforce"))
	var p=board.card(parent,195)
	game.label(p,"Operations / prepare, protect, recover",Rect2(20,10,730,30),22)
	game.button(p,"Jump to equipment",Rect2(780,10,185,34),func():board.content_scroll.scroll_vertical=roundi(equipment_heading.position.y))
	overview=game.paragraph(p,"",Rect2(20,50,930,57),15,game.INK)
	reserves=game.paragraph(p,"",Rect2(20,116,930,70),14,game.MINT)
	var visible_events=sim.ops.events.filter(func(e):return e.phase in ["forecast","active","recovery"])
	visible_events.sort_custom(func(a,b):
		var pa=["active","recovery","forecast"].find(a.phase)*10+["outage","grid_maintenance","heatwave"].find(a.kind)
		var pb=["active","recovery","forecast"].find(b.phase)*10+["outage","grid_maintenance","heatwave"].find(b.kind)
		return a.start<b.start if pa==pb else pa<pb)
	if visible_events.is_empty():
		p=board.card(parent,88)
		game.label(p,"No current weather / grid warning",Rect2(20,11,930,28),20,game.MINT)
		game.paragraph(p,"Heat and planned grid work give 12h notice. Surprise faults do not. Keep battery charge and fuel ready; forecasts and impacts can pause time in Settings.",Rect2(20,46,930,39),14)
	for event in visible_events:
		p=board.card(parent,132)
		game.label(p,Ops.NAMES[event.kind]+" / "+event.phase.to_upper(),Rect2(20,10,930,29),22,game.GOLD)
		var row=game.paragraph(p,"",Rect2(20,49,930,75),14,game.INK)
		event_rows.append({"event":event,"text":row})
	p=board.card(parent,286)
	game.label(p,"Backup power and mobile cooling",Rect2(20,10,930,30),22)
	gear_label=game.paragraph(p,"",Rect2(20,49,930,82),14,game.INK)
	battery_button=game.button(p,"+ Battery · $1,800",Rect2(20,140,290,40),func():perform("battery"))
	generator_button=game.button(p,"+ Generator · $2,600",Rect2(335,140,290,40),func():perform("generator"))
	fuel_button=game.button(p,"Refuel · up to $600",Rect2(650,140,315,40),func():perform("fuel"))
	rental_button=game.button(p,"Hire cooling · $750 / 24h",Rect2(20,194,440,40),func():perform("rental"))
	warm_button=game.button(p,"",Rect2(480,194,485,40),func():perform("warm"))
	game.paragraph(p,"Battery: 240 MW-h / 120 MW. Generator: 180 MW after 1h startup. Warm standby takes 1h to prepare, then costs $6/h + 0.1 fuel per generator/hour. Batteries bridge surprises.",Rect2(20,243,930,38),12)
	p=board.card(parent,122)
	game.label(p,"Preventive maintenance contract",Rect2(20,10,720,29),21)
	game.paragraph(p,"$3/h per building reduces wear 70%. At condition <35%, crews service one building at a time, charging the normal visit fee. Base visits take 2h (service) / 4h (repair); engineers reduce new visit times.",Rect2(20,49,710,64),14)
	crews_button=game.button(p,"",Rect2(780,35,185,42),func():perform("crews"))
	p=board.card(parent,110)
	game.label(p,"Backup hub / physical connection",Rect2(20,10,720,28),20)
	game.paragraph(p,"Backup gear needs its hub substation operating. Before servicing or clearing it, select another owned substation in the town and relocate the equipment ($500).",Rect2(20,48,710,53),14)
	game.button(p,"Move to selected",Rect2(780,38,185,42),func():perform("move_hub"))
	equipment_heading=board.card(parent,65)
	game.label(equipment_heading,"EQUIPMENT / CONDITION AND SERVICE",Rect2(20,15,930,30),20)
	var lots=sim.lots.filter(func(lot):return sim.BUILDINGS.has(lot.kind))
	lots.sort_custom(func(a,b):return sim.cell(int(a.x),int(a.y))==game.selected and sim.cell(int(b.x),int(b.y))!=game.selected)
	if lots.is_empty(): game.paragraph(equipment_heading,"Build a campus to begin operating equipment.",Rect2(20,42,930,20),13)
	for lot in lots:
		var idx=sim.cell(int(lot.x),int(lot.y))
		p=board.card(parent,140)
		game.label(p,"%s T%d · %02d-%02d" % [sim.BUILDINGS[lot.kind].name,lot.level,lot.x+1,lot.y+1],Rect2(20,10,720,29),21)
		var status=game.paragraph(p,"",Rect2(20,49,720,81),14,game.INK)
		game.button(p,"Locate",Rect2(780,13,185,34),func():board.visible=false;game.focus_lot(idx))
		var visit=game.button(p,"",Rect2(780,69,185,43),func():
			game.ask("Service this building?","Cost %s. Equipment will be offline for %dh. Customer deadlines keep running. Backup gear cannot use a hub that is being serviced." % [game.money(Ops.service_cost(lot)),sim.Workforce.duration(sim,4 if lot.failed else 2)],func():perform("service",idx)))
		equipment_rows.append({"lot":lot,"status":status,"button":visit})
	if not sim.ops.results.is_empty():
		p=board.card(parent,58+sim.ops.results.size()*55)
		game.label(p,"INCIDENT RESULTS / CAMPUS TOTALS DURING EACH INCIDENT",Rect2(20,10,930,27),14,game.MINT)
		var y=48
		for result in sim.ops.results:
			game.label(p,"%s · %.0f compute-hours lost · %.0f MW-h backup · %.2f fuel" % [result.name,result.lost_compute,result.backup_mwh,result.fuel_used],Rect2(20,y,930,28),14)
			y+=55
		game.label(p,"Overlapping incidents share campus totals; losses are not summed across these rows.",Rect2(20,y-18,930,26),12,game.MUTED)
	update_live()

func perform(action:String,index:int=-2) -> void:
	if index== -2: index=game.selected
	game.complete_action(game.sim.operate(action,index),"Operations updated. Review reserves before resuming time.")

func update_live() -> void:
	if overview==null or not is_instance_valid(overview): return
	var sim=game.sim;var state=sim.ops;var m=sim.metrics()
	var battery_hours=state.charge/maxf(1,m.power_need)
	var fuel_hours=state.fuel*180/maxf(1,m.power_need)
	overview.text="Temperature %d°C · Grid %.0f%% · Online %.0f / %.0f compute\nPower %.1f / %.1f MW · Cooling %.1f / %.1f CU · Resilience operations %s/h" % [m.weather.temperature,m.weather.grid*100,m.compute,m.capacity,m.power,m.power_need,m.cooling,m.cooling_need,game.money_detail(m.operations)]
	reserves.text="Power headroom %.1f MW · Cooling headroom %.1f CU\nStored energy %.0f / %.0f MW-h (~%.1fh at current load; rate limit applies)\nGenerator fuel %.2f / 36 (~%.1fh at current load); output now %.1f MW" % [m.power-m.power_need,m.cooling-m.cooling_need,state.charge,state.batteries*240,battery_hours,state.fuel,fuel_hours,m.generator_output]
	gear_label.text="%d / 3 battery modules · %d / 3 generators · Hub %s\nBattery output %.1f MW · Recharge %.1f MW · Generator startup %s\nMobile cooling: %s · Range 4 blocks · 240 CU / 20 MW · $12/h operation" % [state.batteries,state.generators,("%02d-%02d" % [sim.lots[int(state.hub)].x+1,sim.lots[int(state.hub)].y+1]) if state.hub>=0 else "not installed",m.battery_output,m.battery_recharge,"NO FUEL" if state.generators>0 and state.fuel<=0 else ("ready" if (state.warm and state.warm_ready<=sim.hour) or (state.generator_ready>=0 and sim.hour>=state.generator_ready) else "1h warmup / startup"),("%dh at %02d-%02d" % [state.rental_until-sim.hour,sim.lots[int(state.rental_site)].x+1,sim.lots[int(state.rental_site)].y+1]) if state.rental_until>sim.hour else "not hired"]
	if state.hub>=0 and not m.hub_online: gear_label.text+="\nHUB OFFLINE: repair or relocate it to use backup power."
	battery_button.disabled=state.batteries>=3 or sim.cash<1800
	generator_button.disabled=state.generators>=3 or sim.cash<2600
	fuel_button.disabled=state.generators==0 or state.fuel>=35.99 or sim.cash<minf(12,36-state.fuel)*50
	rental_button.disabled=state.rental_until>sim.hour+4 or sim.cash<750
	warm_button.text="Warm standby: "+(("warming %dh" % (state.warm_ready-sim.hour)) if state.warm and state.warm_ready>sim.hour else ("ON" if state.warm else "OFF"))
	crews_button.text="Crews: "+("ON" if state.crews else "OFF")
	for row in event_rows:
		var e=row.event
		var timing="Starts in %dh / lasts %dh" % [maxi(0,int(e.start)-sim.hour),int(e.end-e.start)] if e.phase=="forecast" else "%dh until full recovery" % maxi(0,int(e.end)+2-sim.hour)
		var remedy="Add cooling reserves or hire mobile chillers before impact." if e.kind=="heatwave" else "Charge batteries, refill fuel and keep a working backup hub."
		var projection=sim.forecast_event(e)
		row.text.text="%s. %s\nFirst-hour projection %.0f / %.0f compute (current condition / charged reserves).\nCampus loss %.0f compute-hours / backup supplied %.0f MW-h so far. Critical services still need 99%% delivery." % [timing,remedy,projection.compute,projection.capacity,e.lost_compute,e.backup_mwh]
	for row in equipment_rows:
		var lot:Dictionary=row.lot
		var remaining=maxi(0,int(lot.service_until)-sim.hour)
		var state_text=("REPAIR / %dh left" % remaining if lot.failed else "SERVICE / %dh left" % remaining) if remaining>0 else ("FAILED / repair required" if lot.failed else ("Derated %.0f%%" % (Ops.condition_factor(lot,sim.hour)*100) if lot.condition<50 else "Operating"))
		row.status.text="Condition %.1f%% · %s\nBelow 50%%, output derates; below 30%%, random failures become possible.\nService restores condition to 100%%. Keep spare utility capacity during downtime." % [lot.condition,state_text]
		row.button.text=("Repair " if lot.failed else "Service ")+game.money(Ops.service_cost(lot))
		row.button.disabled=remaining>0 or int(lot.get("refit_until",0))>sim.hour or sim.cash<Ops.service_cost(lot) or (lot.condition>=99.9 and not lot.failed)
