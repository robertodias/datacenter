extends SceneTree
var checks=0
var failures=0
func expect(value:bool,message:String) -> void:
	checks+=1
	if not value: failures+=1;printerr("FAIL: ",message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	game.paused=true;game.menu.visible=false;game.settings.ui_scale=1.15;game.apply_settings(false,false)
	await process_frame
	game.map_tools.open();game.map_tools.set_layer("Opinion")
	expect(game.map_tools.layer_legend.text==game.map_tools.legend(),"Atlas legend updates with selection")
	game.paused=false;game.map_tools._process(0)
	expect(game.map_tools.time_summary.text.contains("Running"),"Atlas status follows running time")
	game.paused=true;game.map_tools._process(0)
	expect(game.map_tools.time_summary.text.contains("Paused"),"Atlas status follows paused time")
	var mini=game.map_tools.body.get_children().filter(func(n):return n.get_script()==load("res://scripts/minimap.gd"))[0]
	game.town.zoom=2;game.town.update_camera()
	var polygon=mini.camera_footprint()
	expect(polygon.size()==4 and polygon[0].x!=polygon[1].x and polygon[0].y!=polygon[1].y,"Camera footprint preserves diagonal projected edges")
	for resolution in [Vector2i(1152,720),Vector2i(1440,900),Vector2i(3440,1440)]:
		root.size=resolution;await process_frame;game.layout_stage()
		for corner in [game.town.play_area.position,game.town.play_area.end]:
			var rect=game.town.thought_bounds(corner,Vector2(384,100))
			expect(game.town.play_area.encloses(rect),"Thought stays in map at "+str(resolution))
	game.sim.buy(82);game.on_selected(82)
	var ward=game.sim.civic.wards.oldtown;ward.stage=4;ward.stress=40;ward.waiver_until=game.sim.hour+1
	game.refresh_inspector()
	var buttons=game.inspector.find_children("*","Button",true,false)
	expect(buttons.any(func(b):return b.text.begins_with("Server hall") and not b.disabled),"Waiver permits construction control")
	game.sim.tick();game.refresh_hud()
	buttons=game.inspector.find_children("*","Button",true,false)
	expect(buttons.any(func(b):return b.text.begins_with("Server hall") and b.disabled),"Expired waiver updates construction control without reselection")
	await process_frame
	var description=game.inspector.get_children().filter(func(n):return n is Label and n.text.begins_with("Balanced racks\n"))[0]
	expect(description.position.y+description.size.y<=240,"Enlarged hardware description clears the next heading")
	expect(game.site_text(82).length()<150,"Permit message fits bounded inspector")
	game.sim.lots[0].preserved=true
	expect(game.site_text(0).contains("PERMANENT CONSERVATION") and not game.site_text(0).contains("total:"),"Conservation site does not advertise impossible construction")
	if "--capture" in OS.get_cmdline_user_args():
		root.size=Vector2i(1440,900);await process_frame;game.layout_stage();game.town.focus(83)
		game.map_tools.open();game.map_tools.set_layer("Opinion")
		for i in range(4): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Usuario/Development/datacenter/build/review-atlas.png")
		game.map_tools.visible=false
		game.town.mouse_position=game.town.point(game.town.pedestrians[0].pos.x,game.town.pedestrians[0].pos.y,7)
		for i in range(4): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Usuario/Development/datacenter/build/review-thought.png")
	game.queue_free();await process_frame
	print("VISUAL REVIEW: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
