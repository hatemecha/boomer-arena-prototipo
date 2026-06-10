class_name SpriteCrosshair
extends Control

const CROSSHAIR_ATLAS: Texture2D = preload("res://ELR_Crosshairs/ELR_Corsshairs.png")
const INVERT_SHADER: Shader = preload("res://shaders/crosshair_invert.gdshader")
const GRID_COLUMNS: int = 8
const GRID_ROWS: int = 6
const DISPLAY_SIZE: float = 24.0

var _texture_rect: TextureRect
var _invert_material: ShaderMaterial
var _crosshair_index: int = 0
var _is_aiming: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(DISPLAY_SIZE, DISPLAY_SIZE) * 2.0
	_setup_texture_rect()
	_setup_invert_material()
	set_crosshair_index(0)


func set_crosshair_index(index: int) -> void:
	_crosshair_index = clampi(index, 0, GRID_COLUMNS * GRID_ROWS - 1)
	_update_atlas_region()


func set_aiming(value: bool) -> void:
	_is_aiming = value
	modulate.a = 0.88 if _is_aiming else 1.0


func get_atlas_texture(index: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = CROSSHAIR_ATLAS
	var col: int = index % GRID_COLUMNS
	var row: int = index / GRID_COLUMNS
	var cell_width: float = CROSSHAIR_ATLAS.get_width() / float(GRID_COLUMNS)
	var cell_height: float = CROSSHAIR_ATLAS.get_height() / float(GRID_ROWS)
	atlas.region = Rect2(col * cell_width, row * cell_height, cell_width, cell_height)
	atlas.filter_clip = true
	return atlas


func _setup_texture_rect() -> void:
	_texture_rect = TextureRect.new()
	_texture_rect.name = "CrosshairSprite"
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.custom_minimum_size = Vector2(DISPLAY_SIZE, DISPLAY_SIZE)
	_texture_rect.set_anchors_preset(Control.PRESET_CENTER)
	_texture_rect.offset_left = -DISPLAY_SIZE * 0.5
	_texture_rect.offset_top = -DISPLAY_SIZE * 0.5
	_texture_rect.offset_right = DISPLAY_SIZE * 0.5
	_texture_rect.offset_bottom = DISPLAY_SIZE * 0.5
	add_child(_texture_rect)


func _setup_invert_material() -> void:
	_invert_material = ShaderMaterial.new()
	_invert_material.shader = INVERT_SHADER
	if _texture_rect != null:
		_texture_rect.material = _invert_material


func _update_atlas_region() -> void:
	if _texture_rect == null:
		return
	_texture_rect.texture = get_atlas_texture(_crosshair_index)
