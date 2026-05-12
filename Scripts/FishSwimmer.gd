extends TextureRect

const FISH_DISPLAY_HEIGHT: float = 55.0

@export var speed: float = 50.0
@export var is_crab: bool = false
@export var y_position: float = 300.0

var _direction: float = 1.0
var _screen_width: float = 360.0
var _base_y: float = 0.0
var _wave_timer: float = 0.0


func _ready() -> void:
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	_screen_width = viewport_rect.size.x

	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	if texture:
		var aspect: float = float(texture.get_width()) / float(max(texture.get_height(), 1))
		var w: float = round(FISH_DISPLAY_HEIGHT * aspect)
		size = Vector2(w, FISH_DISPLAY_HEIGHT)
		custom_minimum_size = size
		pivot_offset = size / 2.0

	_direction = 1.0 if randf() < 0.5 else -1.0
	position.x = randf_range(40.0, max(_screen_width - 40.0 - size.x, 41.0))
	position.y = y_position - size.y / 2.0
	_base_y = position.y
	_wave_timer = randf() * TAU

	if _direction < 0.0:
		scale.x = -1.0


func _process(delta: float) -> void:
	position.x += speed * _direction * delta

	if position.x > _screen_width + 80.0:
		_direction = -1.0
		scale.x = -1.0
	elif position.x < -size.x - 80.0:
		_direction = 1.0
		scale.x = 1.0

	if not is_crab:
		_wave_timer += delta * 1.5
		position.y = _base_y + sin(_wave_timer) * 5.0
