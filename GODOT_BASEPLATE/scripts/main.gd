extends Node3D
## Baseplate simples: piso plano e cinza, sol, céu e personagem em terceira pessoa.
## Sem recursos externos ou modelos protegidos da Unreal Engine.

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const CAMERA_SCRIPT = preload("res://scripts/camera.gd")

func _ready() -> void:
	_create_world()
	_create_ground()
	var player := CharacterBody3D.new()
	player.name = "Humanoide"
	player.position = Vector3(0.0, 0.04, 0.0)
	player.set_script(PLAYER_SCRIPT)
	add_child(player)

	var game_camera := Camera3D.new()
	game_camera.name = "Camera_3a_pessoa"
	game_camera.set_script(CAMERA_SCRIPT)
	game_camera.set("target", player)
	game_camera.current = true
	add_child(game_camera)
	_create_hint()

func _create_world() -> void:
	var world := WorldEnvironment.new()
	world.name = "Ceu_e_ambiente"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.61, 0.75, 0.90)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.89, 0.91, 0.97)
	env.ambient_light_energy = 0.82
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "Sol"
	sun.rotation_degrees = Vector3(-47.0, -32.0, 0.0)
	sun.light_energy = 1.05
	sun.shadow_enabled = false
	add_child(sun)

func _create_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Baseplate_100x100"
	ground.position = Vector3(0.0, -0.5, 0.0)
	add_child(ground)

	var mesh_instance := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3(100.0, 1.0, 100.0)
	mesh_instance.mesh = cube
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.58, 0.62)
	material.metallic = 0.0
	material.roughness = 0.9
	mesh_instance.material_override = material
	ground.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(100.0, 1.0, 100.0)
	collision.shape = shape
	ground.add_child(collision)

func _create_hint() -> void:
	var ui := CanvasLayer.new()
	ui.name = "Instrucoes"
	add_child(ui)
	var hint := Label.new()
	hint.name = "Controles"
	hint.text = "WASD / setas: andar  |  Mouse: câmera  |  Espaço: pular  |  Esc: sair"
	hint.position = Vector2(16, 14)
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color.WHITE)
	hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	hint.add_theme_constant_override("shadow_offset_x", 1)
	hint.add_theme_constant_override("shadow_offset_y", 2)
	ui.add_child(hint)
