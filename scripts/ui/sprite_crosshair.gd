class_name SpriteCrosshair
extends Control

const CROSSHAIR_ATLAS: Texture2D = preload("res://assets/textures/ui/crosshairs/ELR_Corsshairs.png")
const INVERT_SHADER: Shader = preload("res://shaders/crosshair_invert.gdshader")
const GRID_COLUMNS: int = 8
const GRID_ROWS: int = 6
const STYLE_COUNT: int = GRID_COLUMNS * GRID_ROWS
const MAX_STYLE_INDEX: int = STYLE_COUNT - 1
const CELL_SIZE: int = 16
const DISPLAY_SCALE: int = 2
const DISPLAY_SIZE: float = float(CELL_SIZE * DISPLAY_SCALE)

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
	_crosshair_index = clampi(index, 0, MAX_STYLE_INDEX)
	_update_atlas_region()


func set_aiming(value: bool) -> void:
	_is_aiming = value
	modulate.a = 0.88 if _is_aiming else 1.0


func get_atlas_texture(index: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = CROSSHAIR_ATLAS
	var col: int = index % GRID_COLUMNS
	var row: int = index / GRID_COLUMNS
	atlas.region = Rect2i(col * CELL_SIZE, row * CELL_SIZE, CELL_SIZE, CELL_SIZE)
	atlas.filter_clip = true
	return atlas


func _setup_texture_rect() -> void:
	_texture_rect = TextureRect.new()
	_texture_rect.name = "CrosshairSprite"
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
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
