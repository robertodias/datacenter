extends "res://scripts/town_view.gd"
var recipe: Dictionary

func _ready() -> void:
	art=Art.new(self)
	draw_scale=1.5
	origin=Vector2(128,136)-Vector2((recipe.x-recipe.y)*56,(recipe.x+recipe.y)*28)*draw_scale
	art.network={"power":120,"efficiency":1 if recipe.get("online",false) else 0}

func _process(_delta:float) -> void:
	pass

func _draw() -> void:
	match recipe.type:
		"ground": draw_ground(recipe.x,recipe.y,recipe.get("lot",{}))
		"building": art.draw_building(recipe)
		"tree": art.tree(recipe.x,recipe.y,recipe.variant)
		"lamp": art.lamp(recipe.x,recipe.y)
