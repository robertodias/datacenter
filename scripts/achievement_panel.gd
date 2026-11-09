extends "res://scripts/research_panel.gd"
func draw(parent:Node) -> void:
	var box=section(parent,"Company achievements")
	copy(box,"Achievements belong to this saved company and persist after earning them. Sandbox does not award achievements. These are local achievements; Steam integration is not included in this standalone demo.")
	for id in game.sim.Achievements.ITEMS:
		var item:Dictionary=game.sim.Achievements.ITEMS[id]
		box=section(parent,("[EARNED] " if id in game.sim.achievements else "[   ] ")+item.name)
		copy(box,item.detail)
func update_live() -> void:
	pass
