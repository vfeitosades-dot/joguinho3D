extends Control
## Fictional timing-based circuit puzzle. No functional vehicle electrical instructions.
signal completed
signal click_result(success: bool)

var active := false
var phase := 0.0
var stage := 0
var flash := 0.0
var pulse := 0.0
var target_positions := [0.24, 0.71, 0.38]
var tolerances := [0.105, 0.09, 0.075]
var speeds := [0.65, 0.85, 1.04]
var instruction: Label
var progress: Label
var warning: Label

func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    visible = false
    instruction = _label("LIGAÇÃO DIRETA  //  SIMULAÇÃO", 23, Color("f4f5f8"), -130)
    progress = _label("CIRCUITO 1 / 3", 17, Color("b3c0d1"), 160)
    warning = _label("ESPAÇO  •  SINCRONIZAR PULSO", 15, Color("f1bd79"), 193)

func _label(s: String, font_size: int, color: Color, y_offset: int) -> Label:
    var label := Label.new()
    label.text = s
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.set_anchors_preset(Control.PRESET_CENTER_TOP)
    label.anchor_left = 0
    label.anchor_right = 1
    label.anchor_top = 0.5
    label.anchor_bottom = 0.5
    label.offset_top = y_offset
    label.offset_bottom = y_offset + font_size + 10
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(label)
    return label

func start_puzzle() -> void:
    active = true
    stage = 0
    phase = 0.0
    flash = 0.0
    pulse = 0.0
    visible = true
    _update_labels()
    queue_redraw()

func cancel_puzzle() -> void:
    active = false
    visible = false

func attempt() -> void:
    if not active:
        return
    var d: float = absf(phase - float(target_positions[stage]))
    d = minf(d, 1.0 - d)
    var hit := d <= float(tolerances[stage])
    click_result.emit(hit)
    flash = 0.46
    if hit:
        stage += 1
        warning.text = "PULSO SINCRONIZADO"
        warning.add_theme_color_override("font_color", Color("80f6c4"))
        if stage >= 3:
            active = false
            visible = false
            completed.emit()
        else:
            phase = 0.0
            _update_labels()
    else:
        warning.text = "FORA DE SINCRONIA  ·  TENTE NOVAMENTE"
        warning.add_theme_color_override("font_color", Color("ff8c85"))
    queue_redraw()

func _update_labels() -> void:
    progress.text = "CIRCUITO %d / 3" % (stage + 1)
    warning.text = "ESPAÇO  •  SINCRONIZAR PULSO"
    warning.add_theme_color_override("font_color", Color("f1bd79"))

func _process(delta: float) -> void:
    if not active:
        return
    phase = fposmod(phase + delta * float(speeds[stage]), 1.0)
    flash = maxf(0.0, flash - delta)
    pulse += delta
    queue_redraw()

func _draw() -> void:
    if not active:
        return
    var size_: Vector2 = get_viewport_rect().size
    var center := size_ * 0.5 + Vector2(0, 20)
    draw_rect(Rect2(Vector2.ZERO, size_), Color(0.017, 0.025, 0.039, 0.80))
    draw_rect(Rect2(center - Vector2(224, 212), Vector2(448, 446)), Color(0.036, 0.055, 0.072, 0.95), true)
    draw_rect(Rect2(center - Vector2(224, 212), Vector2(448, 446)), Color(0.20, 0.27, 0.34), false, 1.6)
    var r := 98.0
    draw_arc(center, r, -PI / 2, 3 * PI / 2, 148, Color("324555"), 14.0, true)
    var target := float(target_positions[stage])
    var tol := float(tolerances[stage])
    var start := -PI / 2 + (target - tol) * TAU
    var end := -PI / 2 + (target + tol) * TAU
    draw_arc(center, r, start, end, 26, Color("44efac"), 16.0, true)
    var angle := -PI / 2 + phase * TAU
    var needle := Vector2(cos(angle), sin(angle))
    draw_line(center, center + needle * 94, Color("ffcc76"), 3.7, true)
    draw_circle(center + needle * r, 9.0, Color("ffe2a7"))
    draw_circle(center, 25.0 + sin(pulse * 5.0) * 1.7, Color("1b2936"))
    draw_circle(center, 7.0, Color("c6d9e6"))
    for i in range(3):
        var marker := center + Vector2((i - 1) * 33, 143)
        draw_circle(marker, 7.0, Color("6be0b1") if i < stage else Color("354454"))
    if flash > 0.0:
        draw_rect(Rect2(center - Vector2(224, 212), Vector2(448, 446)), Color(0.24, 1.0, 0.65, 0.08 * flash) if stage > 0 else Color(1.0, 0.20, 0.14, 0.12 * flash))
