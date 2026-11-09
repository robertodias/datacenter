extends SceneTree
var Canvas=load(get_script().resource_path.get_base_dir().path_join("capsule_canvas.gd"))
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var folder="C:/Users/Usuario/Development/datacenter/release/steam/capsules/"
	DirAccess.make_dir_recursive_absolute(folder)
	for spec in [{"name":"header","size":Vector2i(920,430)},{"name":"small","size":Vector2i(462,174)},{"name":"main","size":Vector2i(1232,706)},{"name":"vertical","size":Vector2i(748,896)}]:
		var viewport=SubViewport.new();viewport.size=spec.size;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		var canvas=Canvas.new();canvas.size=spec.size;viewport.add_child(canvas);root.add_child(viewport)
		for frame in range(60): await process_frame
		await RenderingServer.frame_post_draw
		if viewport.get_texture().get_image().save_png(folder+spec.name+".png")!=OK: quit(1);return
		viewport.queue_free();await process_frame
	print("CAPSULES: four original layouts rendered at Steam store dimensions")
	quit()
