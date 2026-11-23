extends CanvasLayer
# Costa Livre — interface original, adaptada a 960x540 e GPU integrada.

const MapScript = preload("res://scripts/map_widget.gd")
const INK := Color(0.035, 0.055, 0.084, 0.95)
const PANEL := Color(0.065, 0.11, 0.15, 0.94)
const TEAL := Color(0.22, 0.89, 0.81)
const SAND := Color(1.0, 0.8, 0.47)
const SOFT := Color(0.72, 0.82, 0.85)
var game: Node3D
var hud: Control
var screen: Control
var menu_card: Panel
var headline: Label
var info_label: Label
var hud_area: Label
var hud_status: Label
var hud_mission: Label
var hud_cash: Label
var hud_toast: Label
var hud_hint: Label
var hud_speed: Label
var map_small: Control
var map_large: Control
var show_help := true
var current_mode := "menu"
var quality := 0
var toast_t := 0.0
var ui_clock := 0.0

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 _create_ui()
 _set_mode("menu")
 _apply_quality(0)

func _style(bg: Color, edge: Color = Color(0.3, 0.48, 0.53, 0.32), radius: int = 12) -> StyleBoxFlat:
 var s := StyleBoxFlat.new()
 s.bg_color = bg
 s.border_color = edge
 s.border_width_left = 1
 s.border_width_top = 1
 s.border_width_right = 1
 s.border_width_bottom = 1
 s.corner_radius_top_left = radius
 s.corner_radius_top_right = radius
 s.corner_radius_bottom_left = radius
 s.corner_radius_bottom_right = radius
 s.content_margin_left = 10.0
 s.content_margin_right = 10.0
 s.content_margin_top = 7.0
 s.content_margin_bottom = 7.0
 return s

func _text(parent: Node, content: String, pos: Vector2, sz: int, color: Color, width: float = 500.0) -> Label:
 var l := Label.new()
 l.text = content
 l.position = pos
 l.size = Vector2(width, 92)
 l.add_theme_font_size_override("font_size", sz)
 l.add_theme_color_override("font_color", color)
 l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
 l.add_theme_constant_override("shadow_offset_y", 1)
 parent.add_child(l)
 return l

func _panel(parent: Node, pos: Vector2, sz: Vector2, bg: Color = PANEL) -> Panel:
 var p := Panel.new()
 p.position = pos
 p.size = sz
 p.add_theme_stylebox_override("panel", _style(bg))
 parent.add_child(p)
 return p

func _button(parent: Node, content: String, pos: Vector2, sz: Vector2, primary: bool, cb: Callable) -> Button:
 var b := Button.new()
 b.text = content
 b.position = pos
 b.size = sz
 b.add_theme_font_size_override("font_size", 17)
 b.add_theme_color_override("font_color", INK if primary else SOFT)
 b.add_theme_color_override("font_hover_color", Color.WHITE)
 b.add_theme_stylebox_override("normal", _style(TEAL if primary else Color(0.12, 0.20, 0.25, 0.98)))
 b.add_theme_stylebox_override("hover", _style(Color(0.12, 0.72, 0.71)))
 b.add_theme_stylebox_override("pressed", _style(Color(0.10, 0.48, 0.52)))
 b.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0)))
 b.pressed.connect(cb)
 parent.add_child(b)
 return b

func _create_ui() -> void:
 hud = Control.new()
 hud.name = "HUD_Costa_Livre"
 hud.set_anchors_preset(Control.PRESET_FULL_RECT)
 hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(hud)

 _panel(hud, Vector2(15, 14), Vector2(314, 70))
 _text(hud, "C O S T A   L I V R E", Vector2(29, 19), 23, TEAL, 300)
 hud_area = _text(hud, "CENTRO  /  CIDADE LITORANEA", Vector2(29, 51), 12, SOFT, 300)

 _panel(hud, Vector2(651, 14), Vector2(294, 105))
 _text(hud, "OBJETIVO ATUAL", Vector2(666, 22), 12, TEAL, 264)
 hud_mission = _text(hud, "Explore a cidade", Vector2(666, 47), 16, Color.WHITE, 264)
 hud_mission.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 hud_cash = _text(hud, "CREDITOS  R$ 0000", Vector2(666, 87), 12, SAND, 270)

 _panel(hud, Vector2(14, 363), Vector2(212, 164))
 _text(hud, "MAPA  /  M PARA AMPLIAR", Vector2(25, 371), 11, TEAL, 195)
 map_small = MapScript.new()
 map_small.position = Vector2(24, 395)
 map_small.size = Vector2(190, 121)
 map_small.game = game
 map_small.mouse_filter = Control.MOUSE_FILTER_IGNORE
 hud.add_child(map_small)

 _panel(hud, Vector2(757, 440), Vector2(189, 87))
 hud_speed = _text(hud, "A PE   00 KM/H", Vector2(770, 447), 20, Color.WHITE, 170)
 hud_status = _text(hud, "MUNDO ABERTO", Vector2(771, 484), 12, SOFT, 168)
 hud_hint = _text(hud, "WASD ANDAR  •  SHIFT CORRER  •  E VEICULO\nF CONVERSAR  •  M MAPA  •  ESC PAUSAR", Vector2(248, 480), 12, Color("dae8e7"), 500)
 hud_toast = _text(hud, "", Vector2(250, 426), 17, SAND, 520)
 hud_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

 screen = Control.new()
 screen.name = "Menu_Costa_Livre"
 screen.set_anchors_preset(Control.PRESET_FULL_RECT)
 screen.mouse_filter = Control.MOUSE_FILTER_STOP
 add_child(screen)
 var tint := ColorRect.new()
 tint.color = Color(0.012, 0.033, 0.055, 0.83)
 tint.set_anchors_preset(Control.PRESET_FULL_RECT)
 tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
 screen.add_child(tint)
 _text(screen, "ESTUDIO  ·  PROJETO ORIGINAL", Vector2(56, 43), 14, TEAL, 520)
 _text(screen, "COSTA", Vector2(52, 99), 67, Color.WHITE, 520)
 _text(screen, "LIVRE", Vector2(53, 176), 70, TEAL, 520)
 _text(screen, "UMA CIDADE. MUITOS CAMINHOS.", Vector2(58, 270), 16, SOFT, 550)
 _text(screen, "Explore a orla, dirija, descubra bairros e conheca moradores.", Vector2(58, 308), 13, Color("cfdcdb"), 610)
 _text(screen, "VERSAO 0.2  |  EXPERIMENTAL  |  MODO COMPATIBILIDADE", Vector2(58, 505), 11, Color("83aeb8"), 760)
 menu_card = _panel(screen, Vector2(592, 74), Vector2(325, 389), Color(0.035, 0.077, 0.102, 0.98))
 headline = _text(menu_card, "ESCOLHA SUA ROTA", Vector2(20, 22), 24, Color.WHITE, 280)
 info_label = _text(menu_card, "Mundo aberto com carros e missoes civis.", Vector2(22, 62), 12, SOFT, 270)
 _button(menu_card, "▶   INICIAR EXPLORACAO", Vector2(20, 112), Vector2(283, 54), true, func(): _set_mode("game"))
 _button(menu_card, "CONTINUAR", Vector2(20, 179), Vector2(283, 43), false, func(): _set_mode("game"))
 _button(menu_card, "GRAFICOS E DESEMPENHO", Vector2(20, 232), Vector2(283, 43), false, func(): _set_mode("settings"))
 _button(menu_card, "SAIR", Vector2(20, 293), Vector2(283, 43), false, func(): get_tree().quit())
 
 map_large = MapScript.new()
 map_large.game = game
 map_large.size = Vector2(490, 404)
 map_large.position = Vector2(238, 73)
 map_large.expanded = true
 map_large.visible = false
 add_child(map_large)

func _set_mode(new_mode: String) -> void:
 current_mode = new_mode
 screen.visible = new_mode != "game"
 hud.visible = new_mode == "game"
 map_large.visible = new_mode == "map"
 if new_mode == "game":
  Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
  get_tree().paused = false
 else:
  Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
  get_tree().paused = true
 if new_mode == "menu" or new_mode == "pause":
  headline.text = "MENU PRINCIPAL" if new_mode == "menu" else "JOGO PAUSADO"
  info_label.text = "COSTA LIVRE • Cidade original e exploravel"
  for n in menu_card.get_children():
   if n is Button:
    n.visible = true
 if new_mode == "settings":
  headline.text = "QUALIDADE GRAFICA"
  info_label.text = "Escolha um modo adequado ao seu PC."
  for n in menu_card.get_children():
   if n is Button: n.visible = false
  _build_settings()
 if new_mode == "map":
  headline.text = "MAPA DA CIDADE"
  info_label.text = "Pressione ESC ou M para voltar"
  for n in menu_card.get_children():
   if n is Button: n.visible = false
  menu_card.visible = false
 else:
  menu_card.visible = true
 if game != null and game.player != null:
  game.player.controlling = new_mode == "game" and game.player_car == null

func _build_settings() -> void:
 for node in menu_card.get_children():
  if node.has_meta("dynamic_setting"): node.queue_free()
 var labels = ["ECONOMICO   800x450", "EQUILIBRADO   960x540", "DETALHADO   1280x720"]
 for i in 3:
  var selected := i
  var b := _button(menu_card, labels[i], Vector2(21, 118 + i*54), Vector2(281, 43), i == quality, func(): _apply_quality(selected))
  b.set_meta("dynamic_setting", true)
 var back := _button(menu_card, "VOLTAR", Vector2(21, 296), Vector2(281, 43), false, func(): _set_mode("pause"))
 back.set_meta("dynamic_setting", true)

func _apply_quality(value: int) -> void:
 quality = value
 var resolutions: Array[Vector2i] = [Vector2i(800,450), Vector2i(960,540), Vector2i(1280,720)]
 get_window().size = resolutions[value]
 if game != null:
  game.chunk_radius = 1 if value == 0 else 2
  game.camera.far = 205.0 if value == 0 else (265.0 if value == 1 else 325.0)
  if is_instance_valid(game.sky_light):
   game.sky_light.shadow_enabled = value == 2
  game._stream_blocks(true)
 if current_mode == "settings":
  _set_mode("settings")

func toggle_pause() -> void:
 if current_mode == "game": _set_mode("pause")
 elif current_mode in ["pause","map","settings"]: _set_mode("game")
 elif current_mode == "menu": _set_mode("game")

func toggle_map() -> void:
 if current_mode == "game": _set_mode("map")
 elif current_mode == "map": _set_mode("game")

func blocks_game_input() -> bool:
 return current_mode != "game"

func notify(text_value: String) -> void:
 hud_toast.text = text_value
 toast_t = 5.0

func update_hud(area: String, fps: int, chunk_count: int, car_speed: float) -> void:
 if not is_instance_valid(hud): return
 hud_area.text = "%s  /  ILHA DOURADA" % area
 hud_status.text = "FPS %02d   |   SETORES %d" % [fps,chunk_count]
 hud_speed.text = ("%02d KM/H" % maxi(0,int(absf(car_speed)*3.6))) if game.player_car != null else "EXPLORANDO"
 if game.missions != null:
  hud_mission.text = game.missions.objective_text
  hud_cash.text = "CREDITOS  R$ %04d  |  TAREFAS %d" % [game.missions.credits,game.missions.completed]
 hud_hint.visible = show_help

func _process(delta: float) -> void:
 ui_clock += delta
 if toast_t > 0.0:
  toast_t -= delta
  if toast_t <= 0.0 and is_instance_valid(hud_toast): hud_toast.text = ""

func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode == KEY_ESCAPE:
   toggle_pause()
   get_viewport().set_input_as_handled()
  elif event.keycode == KEY_M:
   toggle_map()
   get_viewport().set_input_as_handled()
