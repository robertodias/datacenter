extends SceneTree
## Isolated UI playtest fixture. Run with -- --qa. Never touches the player's save.
func _initialize() -> void:
	call_deferred("play")

func play() -> void:
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.sim.new_game()
	game.sim.buy(83)
	game.sim.demolish(83)
	game.sim.build(83,"datacenter")
	game.sim.buy(82)
	game.sim.build(82,"power")
	game.sim.buy(99)
	game.sim.build(99,"cooling")
	for i in range(10): game.sim.tick()
	game.sim.notices.clear()
	game.refresh_inspector()
	game.refresh_hud()
	game.business.open("offers")
