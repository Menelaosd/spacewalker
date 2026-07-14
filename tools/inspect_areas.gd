extends SceneTree
## CROP-QA inspector for the prop/craft/asteroid/wreck/astro/element/etc areas.
## Programmatic per-sprite checks + per-directory montages. INSPECTION ONLY.
## Run: godot --headless -s tools/inspect_areas.gd --path .
const SCRATCH := "C:/Users/menel/AppData/Local/Temp/claude/C--Users-menel-OneDrive---------games-spacewalker-godot47/7e4ea51e-90ff-4cf5-a9f6-830ffa3aca60/scratchpad"

# directories to inspect (res:// relative)
const DIRS := [
	"res://assets/props",
	"res://assets/craft",
	"res://assets/asteroids",
	"res://assets/wrecks",
	"res://assets/sprites/astro",
	"res://assets/sprites/elements",
	"res://assets/sprites/intro",
	"res://assets/particles",
]

# thresholds
const EDGE_OPAQUE_FLAG := 0.20   # >20% of an edge row/col opaque => clipped/half-crop
const ALPHA_OPAQUE := 0.5
const GREEN_FRINGE_FLAG := 30    # more than this many green px => flag
const DEGEN_MIN_FILL := 0.004
const WHITESPACE_MARGIN := 0.14  # >14% blank margin on ALL sides => loose trim


func _init() -> void:
	for d in DIRS:
		_inspect_dir(d)
	quit(0)


func _list_pngs(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(ProjectSettings.globalize_path(dir))
	if d == null:
		return out
	d.list_dir_begin()
	var fn := d.get_next()
	while fn != "":
		if not d.current_is_dir() and fn.ends_with(".png"):
			out.append(fn)
		fn = d.get_next()
	d.list_dir_end()
	out.sort_custom(func(a, b): return _natkey(a) < _natkey(b))
	return out


func _natkey(s: String) -> String:
	# zero-pad trailing/embedded numbers so z2 < z10 and s7_2 < s7_10
	var out := ""
	var num := ""
	for ch in s:
		if ch >= "0" and ch <= "9":
			num += ch
		else:
			if num != "":
				out += num.pad_zeros(4)
				num = ""
			out += ch
	if num != "":
		out += num.pad_zeros(4)
	return out


func _inspect_dir(dir: String) -> void:
	var files := _list_pngs(dir)
	var label := dir.get_file()
	print("")
	print("############ %s  (%d png) ############" % [dir, files.size()])
	if files.is_empty():
		print("  (empty)")
		return
	var records := []
	var sizes := {}
	for f in files:
		var img := Image.load_from_file(ProjectSettings.globalize_path("%s/%s" % [dir, f]))
		if img == null:
			print("LOAD-FAIL ", f)
			continue
		img.convert(Image.FORMAT_RGBA8)
		var rec := _analyze(img, f)
		records.append(rec)
		var key := "%dx%d" % [rec.w, rec.h]
		sizes[key] = sizes.get(key, 0) + 1

	print("file             | size      | edgeL edgeR edgeT edgeB | fill%% | bbox%% | margin(l,r,t,b) | green | verdict")
	var halfs := []
	var fringes := []
	var wspace := []
	var n_ok := 0
	for r in records:
		var verdict := _verdict(r)
		if verdict == "OK":
			n_ok += 1
		if r.half_sides.size() > 0:
			halfs.append("%s [%s]" % [r.name, ",".join(r.half_sides)])
		if r.green > GREEN_FRINGE_FLAG:
			fringes.append("%s (%d px)" % [r.name, r.green])
		if r.whitespace:
			wspace.append("%s (bbox %.0f%%)" % [r.name, r.bbox_frac * 100.0])
		print("%-16s | %4dx%-4d | %4.0f%% %4.0f%% %4.0f%% %4.0f%% | %4.1f%% | %4.0f%% | %2d,%2d,%2d,%2d | %5d | %s" % [
			r.name, r.w, r.h,
			r.edge[0]*100, r.edge[1]*100, r.edge[2]*100, r.edge[3]*100,
			r.fill*100, r.bbox_frac*100,
			r.margin[0], r.margin[1], r.margin[2], r.margin[3],
			r.green, verdict])

	print("--- %s summary: %d files, %d OK ---" % [label, records.size(), n_ok])
	print("  sizes: ", sizes)
	print("  HALF-CROP/edge-clipped (%d): %s" % [halfs.size(), ", ".join(halfs)])
	print("  GREEN-FRINGE (%d): %s" % [fringes.size(), ", ".join(fringes)])
	print("  LOOSE-TRIM/whitespace (%d): %s" % [wspace.size(), ", ".join(wspace)])
	_build_montage(dir, files, label)


func _analyze(img: Image, name: String) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var edge := [0.0, 0.0, 0.0, 0.0]
	var cL := 0; var cR := 0
	for y in h:
		if img.get_pixel(0, y).a > ALPHA_OPAQUE: cL += 1
		if img.get_pixel(w-1, y).a > ALPHA_OPAQUE: cR += 1
	var cT := 0; var cB := 0
	for x in w:
		if img.get_pixel(x, 0).a > ALPHA_OPAQUE: cT += 1
		if img.get_pixel(x, h-1).a > ALPHA_OPAQUE: cB += 1
	edge[0] = float(cL)/h; edge[1] = float(cR)/h
	edge[2] = float(cT)/w; edge[3] = float(cB)/w

	var opaque := 0; var green := 0
	var minx := w; var miny := h; var maxx := -1; var maxy := -1
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a > ALPHA_OPAQUE:
				opaque += 1
				if x < minx: minx = x
				if x > maxx: maxx = x
				if y < miny: miny = y
				if y > maxy: maxy = y
			if c.a > 0.3 and c.g > 0.30 and c.g > c.r * 1.2 and c.g > c.b * 1.2:
				green += 1
	var fill := float(opaque)/float(w*h)
	var bbw := 0.0; var bbh := 0.0
	var margin := [0, 0, 0, 0]
	if maxx >= 0:
		bbw = float(maxx-minx+1)/w
		bbh = float(maxy-miny+1)/h
		margin = [minx, w-1-maxx, miny, h-1-maxy]
	var bbox_frac: float = bbw * bbh

	var half_sides := []
	var side_names := ["L", "R", "T", "B"]
	for i in 4:
		if edge[i] > EDGE_OPAQUE_FLAG:
			half_sides.append(side_names[i])

	# loose trim: content bbox small AND all four margins large-ish
	var whitespace := false
	if maxx >= 0 and bbw < 0.72 and bbh < 0.72:
		var ml := float(margin[0])/w; var mr := float(margin[1])/w
		var mt := float(margin[2])/h; var mb := float(margin[3])/h
		if ml > WHITESPACE_MARGIN and mr > WHITESPACE_MARGIN and mt > WHITESPACE_MARGIN and mb > WHITESPACE_MARGIN:
			whitespace = true

	return {
		"name": name, "w": w, "h": h, "edge": edge, "fill": fill,
		"green": green, "half_sides": half_sides, "bbox_frac": bbox_frac,
		"margin": margin, "whitespace": whitespace
	}


func _verdict(r: Dictionary) -> String:
	var parts := []
	if r.half_sides.size() > 0:
		parts.append("EDGE[%s]" % ",".join(r.half_sides))
	if r.green > GREEN_FRINGE_FLAG:
		parts.append("GREEN")
	if r.whitespace:
		parts.append("LOOSE")
	if r.fill < DEGEN_MIN_FILL:
		parts.append("NEAR-EMPTY")
	if parts.is_empty():
		return "OK"
	return " ".join(parts)


func _build_montage(dir: String, files: Array, label: String) -> void:
	var cell := 96          # fixed cell, images scaled to fit
	var cols := 8
	if files.size() <= 20:
		cols = 5
	var pad := 6
	var lblh := 4
	var cw := cell + pad*2
	var ch := cell + pad*2 + lblh
	var rows := int(ceil(float(files.size())/cols))
	var out := Image.create(cw*cols, ch*rows, false, Image.FORMAT_RGBA8)
	# checker background so alpha & fringe are visible
	for y in out.get_height():
		for x in out.get_width():
			var t := ((x/12 + y/12) % 2) == 0
			out.set_pixel(x, y, Color(0.30,0.30,0.33) if t else Color(0.22,0.22,0.25))
	var idx := 0
	for f in files:
		var im := Image.load_from_file(ProjectSettings.globalize_path("%s/%s" % [dir, f]))
		if im == null:
			idx += 1
			continue
		im.convert(Image.FORMAT_RGBA8)
		var iw := im.get_width(); var ih := im.get_height()
		var s: float = min(float(cell)/iw, float(cell)/ih)
		var nw: int = max(1, int(iw*s)); var nh: int = max(1, int(ih*s))
		im.resize(nw, nh, Image.INTERPOLATE_NEAREST)
		var col := idx % cols
		var row := idx / cols
		var ox := col*cw + pad + (cell-nw)/2
		var oy := row*ch + pad + lblh + (cell-nh)/2
		out.blend_rect(im, Rect2i(0,0,nw,nh), Vector2i(ox, oy))
		# index bar top-left of cell
		for lx in range(col*cw+2, col*cw + 2 + (idx % 20) + 1):
			if lx < out.get_width():
				out.set_pixel(lx, row*ch+1, Color(1,0.85,0.1))
		idx += 1
	var outp := "%s/area_%s.png" % [SCRATCH, label]
	out.save_png(outp)
	print("  MONTAGE: %s  (%d cols, cell %dpx, natural-sorted)" % [outp, cols, cell])
