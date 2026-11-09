extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size=Vector2i(1440,900)
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	DisplayServer.window_set_title("Hyperscale: Datacenter Tycoon - Operations QA")
	game.sound_enabled=false
	var s=game.sim
	s.buy(83);s.demolish(83);s.build(83,"datacenter")
	s.buy(82);s.build(82,"power");s.buy(99);s.build(99,"cooling")
	s.accept_contract("bakery");s.accept_contract("support")
	for i in range(24): s.tick()
	s.upgrade(83);s.upgrade(82);s.upgrade(99)
	s.operate("battery");s.operate("generator");s.operate("fuel");s.operate("rental")
	s.Operations.add_event(s.ops,"heatwave",s.hour+1,10,0)
	s.Operations.add_event(s.ops,"outage",s.hour+1,5,0)
	s.lots[99].condition=42.0
	s.tick()
	game.settings.ui_scale=1.15;game.apply_settings(false,false)
	game.refresh_hud();game.refresh_inspector();game.town.invalidate()
	game.handle_operation_alerts();game.business.open("operations")
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/Usuario/Development/datacenter/build/operations-overview.png")
	if "--capture-only" in OS.get_cmdline_user_args():
		game.business.content_scroll.scroll_vertical=500
		for i in range(4): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Usuario/Development/datacenter/build/operations-gear.png")
		game.business.visible=false;game.town.focus(83)
		for i in range(4): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Usuario/Development/datacenter/build/operations-town.png")
		quit()
