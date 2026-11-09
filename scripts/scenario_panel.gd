extends "res://scripts/research_panel.gd"
var objectives:Label
var distinctions:Label
var next_button:Button
func draw(parent:Node) -> void:
	var sim=game.sim;var info:Dictionary=sim.Scenarios.info(sim.scenario_id)
	var box=section(parent,info.name+" / town charter")
	copy(box,info.brief);copy(box,info.goal)
	live=copy(box,"");objectives=copy(box,"")
	box=section(parent,"Optional distinctions")
	copy(box,"At the finale: finish without a rescue grant; finish debt-free; preserve at least three sites and rehouse every displaced family; or maintain the sustainable operating target for 48 consecutive hours. Distinctions are recorded when the town is completed.")
	distinctions=copy(box,"")
	if info.next!="":
		box=section(parent,"The next town / a new company chapter")
		copy(box,"You may continue operating this town after its finale. Moving on starts a fresh company in the next town with its own budget and saves. Save this town before leaving if you want to return.")
		next_button=action(box,"Continue to "+sim.Scenarios.info(info.next).name,func():game.request_leave(func():game.start_company(sim.company_name,info.next,sim.difficulty,false,sim.achievements.duplicate())))
	update_live()
func update_live() -> void:
	var sim=game.sim;var m=sim.metrics()
	live.text="Town complete / free to continue" if sim.campaign_won else "Charter in progress"
	if sim.scenario_id=="sunsprawl": live.text+="\nSustainable target: %.0f / 400 compute · %.1f%% / 95%% uptime · %.1f / 80 water" % [m.compute,m.efficiency*100,m.water_use]
	var lines=PackedStringArray()
	for row in sim.Scenarios.objectives(sim): lines.append(("[DONE] " if row.done else "[   ] ")+row.text)
	objectives.text="\n\n".join(lines)
	distinctions.text="No finale recorded yet." if sim.scenario_progress.completed_hour<0 else ("No optional distinction earned." if sim.scenario_progress.distinctions.is_empty() else "\n".join(sim.scenario_progress.distinctions))
	if next_button!=null: next_button.disabled=not sim.campaign_won
