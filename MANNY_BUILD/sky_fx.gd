extends Node3D
var clouds: Array[MeshInstance3D] = []
var origins: Array[Vector3] = []
var sun_glow: MeshInstance3D
var elapsed: float = 0.0
var sun_direction: Vector3 = Vector3(-0.46, 0.58, -0.65).normalized()

func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var cloud_material := StandardMaterial3D.new()
	cloud_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloud_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	cloud_material.albedo_texture = load("res://assets/garage/cloud.png") as Texture2D
	cloud_material.albedo_color = Color(1.0, 0.98, 0.94, 0.88)
	cloud_material.no_depth_test = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 7081
	for i in range(0 if ResourceLoader.exists("res://assets/garage/real_sky.hdr") else 7):
		var angle: float = TAU * float(i) / 7.0
		var pos := Vector3(cos(angle) * 42.0, 22.0 + rng.randf_range(-3.0, 8.0), sin(angle) * 42.0)
		var cloud := _quad(Vector2(rng.randf_range(19.0, 31.0), rng.randf_range(5.5, 9.0)), cloud_material)
		cloud.position = pos
		clouds.append(cloud)
		origins.append(pos)
	var sun_material := StandardMaterial3D.new()
	sun_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sun_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sun_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sun_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sun_material.albedo_texture = load("res://assets/garage/sun_glow.png") as Texture2D
	sun_material.albedo_color = Color(1.0, 0.86, 0.61, 0.42)
	sun_glow = _quad(Vector2(9, 9), sun_material)

func _quad(size: Vector2, material: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = size
	item.mesh = mesh
	item.material_override = material
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(item)
	return item

func _process(delta: float) -> void:
	elapsed += delta
	for i in range(clouds.size()):
		clouds[i].position = origins[i] + Vector3(sin(elapsed * 0.014 + i) * 9.0, 0, 0)
	var cam := get_viewport().get_camera_3d()
	if cam != null and sun_glow != null:
		sun_glow.global_position = cam.global_position + sun_direction * 62.0
