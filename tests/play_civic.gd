extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func capture(name:String) -> void:
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/Usuario/Development/datacenter/build/"+name+".png")

func run() -> void:
	root.size=Vector2i(1440,900)
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	DisplayServer.window_set_title("Hyperscale: Datacenter Tycoon - Civic QA")
	game.sound_enabled=false;game.settings.ui_scale=1.15;game.apply_settings(false,false)
	game.menu.open("title");await capture("hyperscale-title")
	var s=game.sim
	s.post("grant",20000,"Civic visual test fixture")
	var homes=[]
	for i in range(s.lots.size()):
		if s.lots[i].kind=="house" and s.Civic.ward_for(s.lots[i])=="oldtown": homes.append(i)
	for i in range(3): s.buy(homes[i]);s.demolish(homes[i])
	s.buy(83);s.demolish(83);s.build(83,"datacenter");s.buy(82);s.build(82,"power");s.buy(99);s.build(99,"cooling")
	for i in range(36): s.tick()
	game.menu.visible=false;game.session_started=true;game.paused=true
	game.refresh_hud();game.refresh_inspector();game.town.invalidate();game.open_town("oldtown")
	await capture("civic-overview")
	if "--capture-only" in OS.get_cmdline_user_args():
		game.business.content_scroll.scroll_vertical=830;await capture("civic-responses")
		game.business.visible=false;game.town.focus(homes[0]);await capture("civic-protest")
		root.size=Vector2i(1152,720);game.layout_stage();game.open_town("oldtown");await capture("civic-minimum")
		game.business.visible=false;game.show_help();await capture("help-minimum")
		game.help_dialog.get_texture().get_image().save_png("C:/Users/Usuario/Development/datacenter/build/help-guide.png")
		quit()
