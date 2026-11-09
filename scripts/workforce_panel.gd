extends "res://scripts/research_panel.gd"
const Workforce=preload("res://scripts/workforce.gd")
var team_rows=[]
var dispatches:Label
func draw(parent:Node) -> void:
	var sim=game.sim
	var box=section(parent,"People behind the machines")
	live=copy(box,"")
	copy(box,"Specialist teams are optional and add hourly wages on top of the existing equipment staff cost. Lowering a team count does not cancel a paid visit already underway. Outside contractors remain available for manual repairs.")
	for role in Workforce.ROLES:
		var data:Dictionary=Workforce.ROLES[role]
		box=section(parent,data.name+" / $%d per team-hour" % data.wage)
		copy(box,data.brief)
		var status=copy(box,"")
		var buttons=HBoxContainer.new();buttons.add_theme_constant_override("separation",10);box.add_child(buttons)
		for count in range(4):
			var button=action(buttons,"%d team%s" % [count,"" if count==1 else "s"],func():
				game.ask("Set %s to %d teams?" % [data.name,count],"The new team wage is $%d/h. Existing work and signed customer terms stay fixed." % (count*data.wage),func():game.complete_action(Workforce.set_team(sim,role,count),"Staffing updated.");board.refresh()))
			team_rows.append({"role":role,"count":count,"button":button,"status":status})
	box=section(parent,"Dispatch priority")
	copy(box,"The queue includes failed equipment and equipment below 45% condition. Priorities choose what technicians service next; they do not interrupt an active visit. Visit fees are charged only when a team can afford to dispatch.")
	var options=OptionButton.new();options.custom_minimum_size=Vector2(0,42)
	for priority in Workforce.PRIORITIES: options.add_item(priority)
	options.selected=Workforce.PRIORITIES.find(sim.workforce.priority)
	options.add_theme_font_size_override("font_size",roundi(16*game.settings.ui_scale))
	options.item_selected.connect(func(i):sim.workforce.priority=Workforce.PRIORITIES[i];game.dirty=true)
	box.add_child(options)
	box=section(parent,"Dispatch board / actual site visits")
	copy(box,"Vans approach active jobs by road; crews work at the site. Construction and upgrade deliveries finish in two hours, while the building is already usable. Refits and repairs use the actual equipment downtime shown here.")
	dispatches=copy(box,"")
	update_live()
func update_live() -> void:
	var sim=game.sim
	live.text="Specialist wages $%.2f/h · Technician slots %d · Service %dh / repair %dh / refit %dh" % [Workforce.wages(sim),int(sim.workforce.technicians)+(1 if sim.ops.crews else 0),Workforce.duration(sim,2),Workforce.duration(sim,4),Workforce.duration(sim,2)]
	for row in team_rows:
		row.status.text="Current: %d teams · $%d/h" % [sim.workforce[row.role],sim.workforce[row.role]*Workforce.ROLES[row.role].wage]
		row.button.disabled=sim.workforce[row.role]==row.count
	var lines=PackedStringArray()
	for job in sim.workforce.jobs:
		var lot:Dictionary=sim.lots[int(job.site)]
		lines.append("%s · %02d-%02d · %dh remaining" % [job.kind.capitalize(),lot.x+1,lot.y+1,maxi(0,int(job.end)-sim.hour)])
	for lot in sim.lots:
		if lot.kind in sim.BUILDINGS and (lot.get("failed",false) or lot.get("condition",100)<45) and int(lot.get("service_until",0))<=sim.hour:
			var reason="No technician team assigned" if sim.workforce.technicians==0 else ("Waiting for visit funds" if sim.cash<sim.Operations.service_cost(lot) else "Waiting for a dispatch slot")
			lines.append("%02d-%02d · %s · visit $%d" % [lot.x+1,lot.y+1,reason,sim.Operations.service_cost(lot)])
	if lines.is_empty(): lines.append("No visits underway. New builds, upgrades, refits and service dispatches appear here.")
	if not sim.workforce.history.is_empty():
		lines.append("\nLast completed visits")
		for job in sim.workforce.history.slice(0,8): lines.append("%s · %02d-%02d · day %d, %02d:00" % [job.kind.capitalize(),int(job.site)%16+1,int(job.site)/16+1,int(job.end)/24+1,int(job.end)%24])
	dispatches.text="\n".join(lines)
