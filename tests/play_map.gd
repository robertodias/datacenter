extends SceneTree
## Isolated native review fixture. Does not read or overwrite the player's saves.
func _initialize() -> void:
	call_deferred("preview")

func preview() -> void:
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	DisplayServer.window_set_title("Hyperscale: Datacenter Tycoon - Town Atlas QA")
	game.sim.buy(83);game.sim.demolish(83);game.sim.build(83,"datacenter")
	game.sim.buy(82);game.sim.build(82,"power")
	game.sim.buy(99);game.sim.build(99,"cooling")
	game.sim.cash=22000
	game.sim.finance=game.sim.Economy.new_finance(game.sim.cash,game.sim.hour)
	game.sim.buy(91);game.sim.demolish(91);game.sim.build(91,"datacenter")
	game.refresh_inspector();game.refresh_hud();game.town.invalidate()
	game.map_tools.open()
