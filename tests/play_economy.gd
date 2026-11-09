extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	DisplayServer.window_set_title("Hyperscale: Datacenter Tycoon - Economy QA")
	game.sound_enabled=false
	game.sim.buy(83);game.sim.demolish(83);game.sim.build(83,"datacenter","efficient")
	game.sim.buy(82);game.sim.build(82,"power");game.sim.buy(99);game.sim.build(99,"cooling")
	game.sim.accept_contract("bakery");game.sim.accept_contract("support")
	for i in range(24): game.sim.tick()
	game.sim.take_operation_alerts() # This fixture reviews finances after acknowledging the first forecast.
	game.sim.borrow()
	game.dirty=true
	if "--close-test" in OS.get_cmdline_user_args(): game.autosave=-10000
	game.refresh_hud();game.refresh_inspector();game.town.invalidate()
	game.settings.ui_scale=1.15;game.apply_settings(false,false)
	game.business.open("finance")
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/Usuario/Development/datacenter/build/economy-finances.png")
	if "--capture-only" in OS.get_cmdline_user_args():
		game.business.open("hardware")
		for i in range(4): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Usuario/Development/datacenter/build/economy-hardware.png")
		game.business.open("offers")
		for i in range(4): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Usuario/Development/datacenter/build/economy-offers.png")
		quit()
