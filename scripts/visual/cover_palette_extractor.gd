class_name CoverPaletteExtractor
extends RefCounted

const SAMPLE_SIZE := 16
const TARGET_COLORS := 5
const MIN_SATURATION := 0.18
const MAX_BRIGHTNESS := 0.88
const MIN_BRIGHTNESS := 0.22
const MIN_HUE_SEPARATION := 0.10
const MAX_SATURATION := 0.72

var _cache: Dictionary = {}


func extract(cover: Texture2D, track_index: int) -> PackedColorArray:
	if _cache.has(track_index):
		return _cache[track_index]

	var palette := PackedColorArray()
	if cover == null:
		_cache[track_index] = _fallback_palette()
		return _cache[track_index]

	var image: Image = cover.get_image()
	if image == null:
		_cache[track_index] = _fallback_palette()
		return _cache[track_index]

	image.resize(SAMPLE_SIZE, SAMPLE_SIZE, Image.INTERPOLATE_NEAREST)
	image.convert(Image.FORMAT_RGB8)

	var candidates := _collect_candidates(image)
	palette = _select_palette(candidates)

	_cache[track_index] = palette
	return palette


func _collect_candidates(image: Image) -> Array[Color]:
	var bucket_size := 4
	var buckets: Dictionary = {}

	for y in SAMPLE_SIZE:
		for x in SAMPLE_SIZE:
			var c: Color = image.get_pixel(x, y)
			var h: float = c.h
			var s: float = c.s
			var v: float = c.v

			if s < MIN_SATURATION or v < MIN_BRIGHTNESS or v > MAX_BRIGHTNESS:
				continue

			var bh := int(h * (360.0 / bucket_size))
			var bs := int(s * (1.0 / 0.25))
			var bv := int(v * (1.0 / 0.25))
			var key := "%d_%d_%d" % [bh, bs, bv]

			if not buckets.has(key):
				buckets[key] = {"color": c, "count": 0}
			buckets[key]["count"] += 1

	var sorted_candidates: Array[Color] = []
	var entries := buckets.values()
	entries.sort_custom(func(a, b): return a["count"] > b["count"])

	for entry in entries:
		sorted_candidates.append(entry["color"])

	return sorted_candidates


func _select_palette(candidates: Array[Color]) -> PackedColorArray:
	var selected: Array[Color] = []

	for c in candidates:
		if selected.size() >= TARGET_COLORS:
			break
		if _is_sufficiently_different(c, selected):
			selected.append(_psxify(c))

	while selected.size() < TARGET_COLORS:
		var fallback := _fallback_palette()
		selected.append(fallback[selected.size() % fallback.size()])

	var result := PackedColorArray()
	for c in selected:
		result.append(c)
	return result


func _is_sufficiently_different(candidate: Color, existing: Array[Color]) -> bool:
	for e in existing:
		var hue_diff := absf(candidate.h - e.h)
		if hue_diff > 0.5:
			hue_diff = 1.0 - hue_diff
		if hue_diff < MIN_HUE_SEPARATION:
			return false
	return true


func _psxify(c: Color) -> Color:
	var h: float = c.h
	var s: float = clampf(c.s * 0.72, 0.25, MAX_SATURATION)
	var v: float = clampf(c.v * 0.82, MIN_BRIGHTNESS, 0.78)
	return Color.from_hsv(h, s, v)


func get_fallback_palette() -> PackedColorArray:
	return _fallback_palette()


func _fallback_palette() -> PackedColorArray:
	var p := PackedColorArray()
	p.append(Color(0.72, 0.18, 0.18))
	p.append(Color(0.18, 0.36, 0.72))
	p.append(Color(0.18, 0.62, 0.42))
	p.append(Color(0.62, 0.52, 0.18))
	p.append(Color(0.52, 0.18, 0.62))
	return p
