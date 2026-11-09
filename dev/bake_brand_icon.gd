extends SceneTree
## Format conversion only: preserve the generated PNG's alpha in all Windows sizes.
func _initialize() -> void:
	var source=Image.load_from_file("res://assets/branding/hyperscale-icon.png")
	if source==null or source.is_empty(): quit(1);return
	var buffers:Array=[]
	var sizes=[16,24,32,48,64,128,256]
	for edge in sizes:
		var raster=source.duplicate()
		raster.resize(edge,edge,Image.INTERPOLATE_LANCZOS)
		buffers.append(raster.save_png_to_buffer())
	var file=FileAccess.open("res://assets/branding/hyperscale.ico",FileAccess.WRITE)
	file.store_16(0);file.store_16(1);file.store_16(sizes.size())
	var offset=6+16*sizes.size()
	for i in range(sizes.size()):
		var edge:int=sizes[i]
		file.store_8(0 if edge==256 else edge);file.store_8(0 if edge==256 else edge)
		file.store_8(0);file.store_8(0);file.store_16(1);file.store_16(32)
		file.store_32(buffers[i].size());file.store_32(offset);offset+=buffers[i].size()
	for buffer in buffers: file.store_buffer(buffer)
	file.close()
	print("BRAND ICON: seven RGBA Windows sizes; transparent corner alpha ",source.get_pixel(0,0).a)
	quit()
