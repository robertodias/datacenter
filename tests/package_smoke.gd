extends SceneTree
var checks=0
var failures=0
func expect(ok:bool,message:String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("FAIL: ",message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	expect(ProjectSettings.get_setting("application/config/version")=="1.2.0","Extracted executable embeds version 1.2.0")
	expect(not FileAccess.file_exists("res://tests/test_clients.gd") and not FileAccess.file_exists("res://release/steam/screenshots/01-first-campus.png"),"Game pack excludes tests and marketing media")
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await process_frame
	expect(game.menu.visible and game.menu.mode=="title","Extracted standalone starts at the title screen")
	game.saves.directory="user://package_smoke_slots";game.saves.latest_path="";DirAccess.make_dir_recursive_absolute(game.saves.directory)
	await game.start_company("Portable verification","littlebrook","standard")
	expect(game.sim.lots.size()==256 and game.paused,"Fresh town loads from the embedded resources")
	expect(game.sim.contract_definition("bakery").client=="GPN","Final fictional contract content is packaged")
	game.business.open("clients");await process_frame
	expect(game.business.body.find_children("*","Label",true,false).any(func(l):return l.text.contains("SmilingFace")),"Company directory is in the final package")
	game.menu.open("credits");await process_frame
	expect(game.menu.body.find_children("*","Label",true,false).any(func(l):return l.text.contains("synthesized music")),"Final credits include original music")
	game.menu.visible=false;root.size=Vector2i(1152,720);game.settings.ui_scale=1.15;game.apply_settings(false,false);game.show_help()
	await create_timer(1).timeout
	var help_labels=game.help_dialog.find_children("*","Label",true,false)
	expect(help_labels.any(func(l):return l.text=="FEED THE AI") and help_labels.any(func(l):return l.text=="THREE TOWNS, YOUR PACE"),"Extracted game includes the expanded research, staffing and town help")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/Usuario/Development/datacenter/build/final-help.png")
	game.queue_free();await process_frame;await create_timer(0.1).timeout
	print("EXTRACTED PACKAGE: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
