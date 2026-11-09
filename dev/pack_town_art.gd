extends SceneTree
## Packs the delivered town sprites (assets/art, listed in assets/art/manifest.json) into
## a few 2048 x 2048 texture pages the game loads at start.
##
## Each sprite is trimmed to its visible pixels and placed with padding, so mipmaps do not
## bleed between neighbours. The JSON keeps every sprite's trim offset, canvas, anchor and
## animation anchors (fans, steam, crane hook, turbine hub, billboard corners).
##
## Run after the art changes:
##   godot --headless --path . --script res://dev/pack_town_art.gd
##   godot --headless --path . --import
const PAGE=2048
const PAD=8
const MARGIN=2

func _initialize() -> void:
	var manifest:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/manifest.json"))
	var items:Array=[]
	for entry in manifest:
		var path=ProjectSettings.globalize_path("res://assets/art/"+entry.file)
		var image=Image.load_from_file(path)
		if image==null: push_error("Missing sprite "+entry.file);continue
		image.convert(Image.FORMAT_RGBA8)
		var used:Rect2i=image.get_used_rect()
		if used.size.x==0: used=Rect2i(0,0,1,1)
		used=used.grow(MARGIN).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
		items.append({"entry":entry,"image":image,"used":used})
	# Tallest first gives tidy shelves.
	items.sort_custom(func(a,b):return a.used.size.y>b.used.size.y)
	var pages:Array=[]
	var meta:Dictionary={}
	var page:Image=null
	var cursor=Vector2i(PAD,PAD)
	var shelf=0
	for item in items:
		var size:Vector2i=item.used.size
		if page!=null and cursor.x+size.x+PAD>PAGE:
			cursor=Vector2i(PAD,cursor.y+shelf+PAD);shelf=0
		if page==null or cursor.y+size.y+PAD>PAGE:
			page=Image.create(PAGE,PAGE,false,Image.FORMAT_RGBA8);pages.append(page)
			cursor=Vector2i(PAD,PAD);shelf=0
		page.blit_rect(item.image,item.used,cursor)
		var e:Dictionary=item.entry
		var record={"page":pages.size()-1,"rect":[cursor.x,cursor.y,size.x,size.y],"offset":[item.used.position.x,item.used.position.y],
			"canvas":e.canvas,"anchor":e.anchor,"category":e.category}
		for k in ["fans","steam","hook","hub","billboard_corners","direction","layer"]:
			if e.has(k) and not (e[k] is Array and e[k].is_empty()): record[k]=e[k]
		meta[e.key]=record
		cursor.x+=size.x+PAD;shelf=maxi(shelf,size.y)
	var names:Array=[]
	for i in range(pages.size()):
		var name="res://assets/town_art_%d.png" % i
		# Trim the last page to the rows in use.
		var image:Image=pages[i]
		if i==pages.size()-1:
			var used:Rect2i=image.get_used_rect()
			var height=mini(PAGE,int(ceil((used.end.y+PAD)/256.0))*256)
			image=image.get_region(Rect2i(0,0,PAGE,height))
		image.save_png(name);names.append(name)
		var import_path=name+".import"
		if not FileAccess.file_exists(import_path):
			var f=FileAccess.open(import_path,FileAccess.WRITE)
			f.store_string("[remap]\n\nimporter=\"texture\"\ntype=\"CompressedTexture2D\"\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=true\nmipmaps/limit=-1\nprocess/fix_alpha_border=true\nprocess/premult_alpha=false\ndetect_3d/compress_to=0\n")
			f.close()
	var file=FileAccess.open("res://assets/town_art.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"pages":names,"sprites":meta},"\t"))
	file.close()
	print("PACKED %d sprites into %d pages" % [meta.size(),pages.size()])
	quit()
