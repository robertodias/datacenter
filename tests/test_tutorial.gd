extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var checks=0
var failures=0
func expect(value:bool,message:String) -> void:
	checks+=1
	if not value: failures+=1;printerr("FAIL: ",message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	game.paused=true;game.menu.visible=false;game.settings.auto_pause=false
	game.settings.ui_scale=1.15;game.apply_settings(false,false)
	var s=game.sim
	expect(s.tutorial.enabled and s.Tutorial.current(s).id=="inspect","New town begins with a skippable inspection step")
	game.on_selected(83);game.refresh_hud()
	expect(s.Tutorial.current(s).id=="buy" and game.guided_control==game.tools_buttons.buy,"Inspection advances guidance and highlights purchasing")
	game.complete_action(s.buy(83),"Bought");expect(s.Tutorial.current(s).id=="clear","Actual purchase advances guide")
	game.complete_action(s.demolish(83),"Cleared");expect(s.Tutorial.current(s).id=="build","Actual clearance advances guide")
	game.complete_action(s.build(83,"datacenter"),"Built")
	expect(s.Tutorial.current(s).id=="build","Disconnected hall cannot satisfy working-campus objective")
	s.buy(82);s.build(82,"power");s.buy(99);game.complete_action(s.build(99,"cooling"),"Connected")
	expect(s.Tutorial.current(s).id=="revenue","Real online capacity advances campus step")
	var hour=s.hour;game.paused=false;game.accumulator=0
	for i in range(15): game._process(0.25)
	expect(s.hour==hour,"Default clock leaves four seconds per game hour")
	game._process(0.25);game.paused=true
	expect(s.hour==hour+1,"Default clock advances at the stated pace")
	for i in range(9): s.tick()
	game.refresh_hud();expect(s.Tutorial.current(s).id=="customer","Earned revenue unlocks customer guidance")
	game.complete_action(s.accept_contract("bakery"),"Signed");s.accept_contract("support")
	expect(s.Tutorial.current(s).id=="upgrade","Real signed commitment advances the checklist")
	for i in range(24): s.tick()
	game.complete_action(s.upgrade(83),"Upgraded")
	expect("upgrade" in s.tutorial.done,"Paid tier upgrade satisfies improvement")
	s.ops.events.clear();Sim.Operations.add_event(s.ops,"grid_maintenance",s.hour+4,4,12);s.tick();s.operate("battery");Sim.Tutorial.capture(s)
	expect("prepare" in s.tutorial.done,"Appropriate backup purchase during forecast satisfies preparation")
	game.on_selected(39);game.open_town();game.refresh_hud()
	expect(s.Tutorial.current(s).is_empty() and "dilemma" in s.tutorial.done,"Inspecting heritage and reviewing council completes the introduction")
	s.tutorial.enabled=false;s.save_game("user://tutorial-test.json")
	var loaded=Sim.new();expect(loaded.load_game("user://tutorial-test.json") and loaded.tutorial==s.tutorial,"Guide progress and skip preference survive save/load")
	game.business.open("tutorial");await process_frame
	expect(game.business.tutorial_view.guide_button.text.contains("Resume"),"Experienced players can resume a skipped guide")
	game.business.tutorial_view.guide_button.pressed.emit();expect(s.tutorial.enabled,"Resume restores guidance without erasing progress")
	var broken={"enabled":true,"done":["inspect","inspect"]}
	expect(not Sim.Tutorial.valid(broken),"Duplicate or invalid guide records reject")
	root.size=Vector2i(1152,720)
	for i in range(30): await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("C:/Users/Usuario/Development/datacenter/build/tutorial-minimum.png")
	game.queue_free();await process_frame;DirAccess.remove_absolute("user://tutorial-test.json")
	print("TUTORIAL: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
