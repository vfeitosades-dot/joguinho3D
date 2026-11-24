extends Control
var speed: float = 0.0
var displayed: float = 0.0
var max_speed: float = 100.0
var throttle: float = 0.0
var brake: float = 0.0
var gear: String = "P"
var engine_on: bool = false
var impact: float = 0.0

func _process(delta: float) -> void:
	if not visible:
		return
	displayed = lerpf(displayed, speed, 1.0 - exp(-12.0 * delta))
	queue_redraw()

func _draw() -> void:
	var center := Vector2(98, 88)
	var radius: float = 65.0
	var start: float = deg_to_rad(145.0)
	var finish: float = deg_to_rad(395.0)
	var accent := Color(0.36, 0.86, 0.92)
	draw_arc(center, radius, start, finish, 48, Color(0.20, 0.28, 0.34), 7.0, true)
	draw_arc(center, radius, start, lerpf(start, finish, clampf(displayed / maxf(max_speed, 1.0), 0.0, 1.0)), 48, accent, 7.0, true)
	var font := ThemeDB.fallback_font
	var numeral: String = "%03d" % roundi(displayed)
	draw_string(font, Vector2(center.x - 31, 88), numeral, HORIZONTAL_ALIGNMENT_CENTER, 62, 31, Color.WHITE)
	draw_string(font, Vector2(center.x - 28, 108), "km/h", HORIZONTAL_ALIGNMENT_CENTER, 56, 12, Color(0.60, 0.72, 0.79))
	draw_string(font, Vector2(184, 33), "MARCHA", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.55, 0.67, 0.72))
	draw_string(font, Vector2(184, 66), gear, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, accent)
	draw_string(font, Vector2(184, 87), "MOTOR ON" if engine_on else "MOTOR OFF", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, accent if engine_on else Color(0.66, 0.70, 0.74))
	draw_rect(Rect2(184, 98, 85, 5), Color(0.20, 0.28, 0.34))
	draw_rect(Rect2(184, 98, 85 * throttle, 5), accent)
	draw_rect(Rect2(184, 112, 85, 5), Color(0.20, 0.28, 0.34))
	draw_rect(Rect2(184, 112, 85 * brake, 5), Color(0.94, 0.57, 0.32))
	draw_string(font, Vector2(184, 137), "IMPACTO" if impact > 0.2 else "TRAÇÃO ATIVA", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.61, 0.31) if impact > 0.2 else Color(0.62, 0.75, 0.78))
