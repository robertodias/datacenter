extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var recipes:Dictionary={}

func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	var sim=Sim.new()
	for lot in sim.lots:
		if lot.kind in ["grass","road","water"]: continue
		var key=lot.kind
		if key=="house":
			var variant=posmod(int(lot.x*7+lot.y*3),5)
			var shop=(int(lot.x)==3 or int(lot.y)==3) and variant<3
			key="house_%d_%s" % [variant,str(shop)]
		if not recipes.has(key):
			recipes[key]={"type":"building","kind":lot.kind,"x":lot.x,"y":lot.y}
	for kind in ["datacenter","power","cooling"]:
		recipes[kind]={"type":"building","kind":kind,"x":0,"y":0}
	recipes["datacenter_on"]={"type":"building","kind":"datacenter","x":0,"y":0,"online":true}
	for family in range(6): recipes["family_%d" % family]={"type":"building","kind":"house","x":0,"y":0,"family":family}
	for kind in ["datacenter","power","cooling"]:
		for tier in [2,3]:
			for online in [false,true]: recipes["%s_t%d_%s" % [kind,tier,str(online)]]={"type":"building","kind":kind,"x":0,"y":0,"level":tier,"online":online}
	for i in range(4): recipes["tree_"+str(i)]={"type":"tree","x":0,"y":0,"variant":i}
	recipes["lamp"]={"type":"lamp","x":0,"y":0}
	for owned in [false,true]:
		recipes["lot_"+str(owned)]={"type":"ground","x":0,"y":0,"lot":{"owned":owned,"kind":"grass"}}
	for i in range(3): recipes["grass_"+str(i)]={"type":"ground","x":i,"y":1}
	var roads={"road_h":Vector2i(0,4),"road_v":Vector2i(4,0),"junction":Vector2i(4,4),"cross_h3":Vector2i(3,4),"cross_h5":Vector2i(5,4),"cross_v3":Vector2i(4,3),"cross_v5":Vector2i(4,5)}
	for key in roads: recipes[key]={"type":"ground","x":roads[key].x,"y":roads[key].y}
	var atlas=Image.create(2048,ceili(recipes.size()/8.0)*256,false,Image.FORMAT_RGBA8)
	var metadata={}
	var i=0
	for key in recipes:
		var viewport=SubViewport.new()
		viewport.size=Vector2i(256,256)
		viewport.transparent_bg=true
		viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		var canvas=load("res://tests/art_canvas.gd").new()
		canvas.recipe=recipes[key]
		canvas.size=Vector2(256,256)
		viewport.add_child(canvas)
		root.add_child(viewport)
		await process_frame
		await RenderingServer.frame_post_draw
		var rendered=viewport.get_texture().get_image()
		var pos=Vector2i((i%8)*256,(i/8)*256)
		atlas.blit_rect(rendered,Rect2i(0,0,256,256),pos)
		metadata[key]=[pos.x,pos.y,256,256]
		viewport.queue_free()
		i+=1
	DirAccess.make_dir_recursive_absolute("res://assets")
	atlas.save_png("res://assets/town_atlas.png")
	var file=FileAccess.open("res://assets/town_atlas.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata,"\t"))
	file.close()
	print("BAKED ",i," original sprites into one texture atlas")
	quit()
