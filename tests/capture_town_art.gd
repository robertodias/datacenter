extends SceneTree
## Captures the town map with the painted sprite set: three towns, a grown campus and a
## construction in progress. Isolated QA saves only. Run windowed (not headless):
##   godot --path . --script res://tests/capture_town_art.gd -- --qa <output folder>
const Sim=preload("res://scripts/simulation.gd")
var Strategy=load("res://tests/operating_strategy.gd")
var game
var folder="user://town-art/"

func _initialize() -> void: call_deferred("run")

func shot(name:String) -> void:
	game.refresh_hud()
	for i in range(20): await process_frame
	await RenderingServer.frame_post_draw
	var bitmap=root.get_texture().get_image()
	bitmap.save_png(folder.path_join(name+".png"))
	print("SHOT ",name)

func setup(town:String) -> void:
	await game.start_company("Horizon Infrastructure",town,"standard",false)
	var s=game.sim
	s.buy(83);s.demolish(83);s.build(83,"datacenter")
	s.buy(82);s.build(82,"power");s.buy(99);s.build(99,"cooling")
	s.accept_contract("bakery");s.accept_contract("support")
	refresh()

func refresh() -> void:
	game.sim.notices.clear();game.sim.take_operation_alerts();game.sim.take_civic_alerts()
	game.notice_queue.clear();game.announced_win=true;game.announced_campaign=true
	game.toast_timer=0;game.business.visible=false;game.menu.visible=false;game.dialog.hide()
	game.refresh_hud();game.refresh_inspector();game.town.reset_residents();game.town.invalidate()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"): folder=arg
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	game.paused=true;game.settings.auto_pause=false
	await setup("littlebrook")
	game.town.center_view();game.paused=false
	await shot("01-littlebrook")
	game.on_selected(83);game.town.focus(83)
	await shot("02-campus-close")
	# Grow the campus: more halls of each hardware, upgraded utilities.
	game.paused=true
	var s=game.sim
	s.cash+=400000
	for i in range(30): Strategy.tick(s)
	for site in [97,81,98,115,114,113]:
		s.buy(site);s.demolish(site)
	s.build(97,"datacenter","efficient");s.build(81,"datacenter","refurbished")
	s.build(98,"cooling");s.build(115,"datacenter","balanced");s.build(114,"power")
	s.upgrade(83);s.upgrade(83);s.upgrade(82);s.upgrade(99);s.upgrade(97);s.upgrade(115)
	for i in range(72):
		if s.workforce.jobs.filter(func(j):return j.kind in ["construction","upgrade"]).is_empty(): break
		s.tick()
	refresh();game.town.focus(83);game.town.zoom=1.5;game.paused=false
	await shot("03-grown-campus")
	s.build(113,"datacenter");game.town.start_build(113)
	game.town.real_time=0.0;game.town.anims[113].t0=-1.6
	game.town.focus(113)
	await shot("04-construction")
	game.paused=true;await setup("sunsprawl");game.town.center_view();game.paused=false
	await shot("05-sunsprawl")
	game.paused=true;await setup("oldbridge");game.town.center_view();game.paused=false
	await shot("06-oldbridge")
	game.queue_free();await process_frame
	print("TOWN ART CAPTURE done: ",ProjectSettings.globalize_path(folder))
	quit()
