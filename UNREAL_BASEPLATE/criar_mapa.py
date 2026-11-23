"""Executar apenas no Unreal Editor com PythonScriptPlugin habilitado."""
import unreal

MAPA = "/Game/Maps/Baseplate"
levels = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
actors = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)

gamemode = unreal.load_class(
    None,
    "/Game/ThirdPerson/Blueprints/BP_ThirdPersonGameMode.BP_ThirdPersonGameMode_C",
)
if gamemode is None:
    raise RuntimeError("O GameMode Third Person oficial nao foi encontrado.")

if not levels.new_level(MAPA):
    raise RuntimeError("Nao foi possivel criar o mapa.")

cube = unreal.load_asset("/Engine/BasicShapes/Cube.Cube")
if cube is None:
    raise RuntimeError("A malha Cube da engine nao foi encontrada.")

ground = actors.spawn_actor_from_class(
    unreal.StaticMeshActor, unreal.Vector(0, 0, -20), unreal.Rotator(0, 0, 0)
)
ground.set_actor_label("Baseplate")
ground.static_mesh_component.set_static_mesh(cube)
ground.set_actor_scale3d(unreal.Vector(100, 100, 0.4))

start = actors.spawn_actor_from_class(
    unreal.PlayerStart, unreal.Vector(0, 0, 125), unreal.Rotator(0, 0, 0)
)
start.set_actor_label("Spawn_Personagem_Padrao")

sun = actors.spawn_actor_from_class(
    unreal.DirectionalLight, unreal.Vector(0, 0, 600), unreal.Rotator(-45, -30, 0)
)
sun.set_actor_label("Sol")

sky = actors.spawn_actor_from_class(
    unreal.SkyLight, unreal.Vector(0, 0, 400), unreal.Rotator(0, 0, 0)
)
sky.set_actor_label("Iluminacao_Ambiente")

atmos = actors.spawn_actor_from_class(
    unreal.SkyAtmosphere, unreal.Vector(0, 0, 0), unreal.Rotator(0, 0, 0)
)
atmos.set_actor_label("Ceu")

world = unreal.get_editor_subsystem(
    unreal.UnrealEditorSubsystem
).get_editor_world()
world.get_world_settings().set_editor_property(
    "default_game_mode", gamemode
)

if not levels.save_current_level():
    raise RuntimeError("Nao foi possivel salvar o mapa.")

unreal.log("Baseplate salvo em " + MAPA)
