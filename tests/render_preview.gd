extends SceneTree
## Render smoke test: QA save only; includes all three campus buildings.
func _initialize() -> void:
	call_deferred("preview")

func preview() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.toggle_pause()
	scene.sim.new_game()
	scene.sim.buy(83)
	scene.sim.demolish(83)
	scene.sim.build(83,"datacenter")
	scene.sim.buy(82)
	scene.sim.build(82,"power")
	scene.sim.buy(99)
	scene.sim.build(99,"cooling")
	scene.sim.accept_contract("bakery")
	scene.sim.accept_contract("support")
	for i in range(24): scene.sim.tick()
	scene.sim.upgrade(83)
	scene.sim.upgrade(82)
	scene.sim.upgrade(99)
	scene.sim.accept_contract("studio")
	scene.sim.notices.clear()
	scene.sim.take_operation_alerts() # Acknowledge the forecast for this world-render fixture.
	scene.announced_win=true
	scene.refresh_inspector()
	scene.refresh_hud()
	scene.toast_timer=0
	root.size=Vector2i(1920,1080)
	for i in range(120): await process_frame
	print("RENDER FPS: ",Engine.get_frames_per_second())
	print("DRAW CALLS: ",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/graphics-preview.png")
	scene.business.open("active")
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/v1-contracts.png")
	scene.settings.ui_scale=1.15
	scene.apply_settings(false,false)
	scene.map_tools.open()
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/town-atlas-preview.png")
	quit()
