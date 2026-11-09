extends "res://scripts/research_panel.gd"
var checklist:Label
var guide_button:Button
func draw(parent:Node) -> void:
	var box=section(parent,"Your first thirty minutes")
	copy(box,"Learn at your own pace. The guide observes your actions without locking construction or forcing a choice. Pause to inspect; 1× gives four seconds per simulation hour, with 3× and 6× available for waiting. Forecasts can pause time automatically.")
	live=copy(box,"")
	action(box,"Show me the next step",func():board.visible=false;game.guide_next())
	guide_button=action(box,"",func():game.sim.tutorial.enabled=not game.sim.tutorial.enabled;game.dirty=true;game.refresh_hud();board.refresh())
	box=section(parent,"Your company checklist")
	checklist=copy(box,"")
	update_live()
func update_live() -> void:
	var sim=game.sim;var step=sim.Tutorial.current(sim)
	live.text="All introduction steps complete. Open Company → Town charter for your next goals." if step.is_empty() else step.title+"\n"+step.hint
	guide_button.text="Skip guidance / keep progress" if sim.tutorial.enabled else "Resume guidance"
	var rows=PackedStringArray()
	for item in sim.Tutorial.STEPS: rows.append(("[DONE] " if item.id in sim.tutorial.done else "[   ] ")+item.title+"\n"+item.hint)
	checklist.text="\n\n".join(rows)
