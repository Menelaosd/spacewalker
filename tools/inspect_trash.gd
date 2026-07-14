extends SceneTree
## CROP-QA inspector for space-trash sprites.
## Programmatic per-sprite checks + labelled montage. INSPECTION ONLY.
const DIR := "res://assets/sprites/trash"
const MONTAGE_OUT := "C:/Users/menel/AppData/Local/Temp/claude/C--Users-menel-OneDrive---------games-spacewalker-godot47/7e4ea51e-90ff-4cf5-a9f6-830ffa3aca60/scratchpad/trash_inspect_montage.png"

# thresholds
const EDGE_OPAQUE_FLAG := 0.18   # >18% of an edge row/col opaque => clipped
const ALPHA_OPAQUE := 0.5        # alpha above this counts as "opaque"
const GREEN_FRINGE_FLAG := 40    # more than this many green px => flag
const DEGEN_MIN_FILL := 0.004    # opaque area fraction below this => near-empty
const DEGEN_MAX_BBOX := 0.985    # bbox fills >98.5% of canvas each axis => full-canvas
const DUP_DIST := 0.06           # signature distance below this => near-dup

func _init() -> void:
	var files := _list_pngs()
	if files.is_empty():
		print("NO SPRITES FOUND in ", DIR)
		quit(0)
		return
	print("Inspecting %d sprites (%s .. %s)" % [files.size(), files[0], files[files.size() - 1]])
	print("")
	var sigs := {}          # name -> PackedFloat32Array signature
	var records := []       # dicts
	for f in files:
		var path := "%s/%s" % [DIR, f]
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img == null:
			print("LOAD-FAIL ", f)
			continue
		img.convert(Image.FORMAT_RGBA8)
		var rec := _analyze(img, f)
		records.append(rec)
		sigs[f] = _signature(img)

	# duplicate detection
	var names := sigs.keys()
	for i in names.size():
		for j in range(i + 1, names.size()):
			var d := _sig_dist(sigs[names[i]], sigs[names[j]])
			if d < DUP_DIST:
				for r in records:
					if r.name == names[j] and r.dup_of == "":
						r.dup_of = names[i]

	# verdicts + print table
	print("file        | size    | edgeL edgeR edgeT edgeB | fill%% | green | verdict")
	print("------------+---------+-------------------------+-------+-------+--------------------")
	var n_ok := 0
	var halfs := []
	var fringes := []
	var degens := []
	var dups := []
	for r in records:
		var verdict := _verdict(r)
		if verdict == "OK":
			n_ok += 1
		if r.half_sides.size() > 0:
			halfs.append("%s (sides: %s)" % [r.name, ",".join(r.half_sides)])
		if r.green > GREEN_FRINGE_FLAG:
			fringes.append("%s (%d px)" % [r.name, r.green])
		if r.degen != "":
			degens.append("%s (%s)" % [r.name, r.degen])
		if r.dup_of != "":
			dups.append("%s ~ %s" % [r.name, r.dup_of])
		print("%-11s | %4dx%-3d| %4.0f%% %4.0f%% %4.0f%% %4.0f%% | %4.1f%% | %5d | %s" % [
			r.name, r.w, r.h,
			r.edge[0] * 100.0, r.edge[1] * 100.0, r.edge[2] * 100.0, r.edge[3] * 100.0,
			r.fill * 100.0, r.green, verdict])

	print("")
	print("=== SUMMARY ===")
	print("Total inspected: %d   Clean(OK): %d" % [records.size(), n_ok])
	print("HALF-CROP suspects (%d):" % halfs.size())
	for s in halfs:
		print("   ", s)
	print("GREEN-FRINGE suspects (%d):" % fringes.size())
	for s in fringes:
		print("   ", s)
	print("DEGENERATE suspects (%d):" % degens.size())
	for s in degens:
		print("   ", s)
	print("DUPLICATE pairs (%d):" % dups.size())
	for s in dups:
		print("   ", s)

	_build_montage(files)
	quit(0)

func _list_pngs() -> Array:
	var out := []
	var d := DirAccess.open(ProjectSettings.globalize_path(DIR))
	if d == null:
		return out
	d.list_dir_begin()
	var fn := d.get_next()
	while fn != "":
		if not d.current_is_dir() and fn.ends_with(".png"):
			out.append(fn)
		fn = d.get_next()
	d.list_dir_end()
	out.sort()
	return out

func _analyze(img: Image, name: String) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	# per-side edge-opacity fractions: [L, R, T, B]
	var edge := [0.0, 0.0, 0.0, 0.0]
	var cL := 0
	var cR := 0
	for y in h:
		if img.get_pixel(0, y).a > ALPHA_OPAQUE:
			cL += 1
		if img.get_pixel(w - 1, y).a > ALPHA_OPAQUE:
			cR += 1
	var cT := 0
	var cB := 0
	for x in w:
		if img.get_pixel(x, 0).a > ALPHA_OPAQUE:
			cT += 1
		if img.get_pixel(x, h - 1).a > ALPHA_OPAQUE:
			cB += 1
	edge[0] = float(cL) / float(h)
	edge[1] = float(cR) / float(h)
	edge[2] = float(cT) / float(w)
	edge[3] = float(cB) / float(w)

	# fill fraction + green residue + bbox
	var opaque := 0
	var green := 0
	var minx := w
	var miny := h
	var maxx := -1
	var maxy := -1
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
	var fill := float(opaque) / float(w * h)

	var half_sides := []
	var side_names := ["L", "R", "T", "B"]
	for i in 4:
		if edge[i] > EDGE_OPAQUE_FLAG:
			half_sides.append(side_names[i])

	var degen := ""
	if fill < DEGEN_MIN_FILL:
		degen = "near-empty"
	else:
		var bbw := float(maxx - minx + 1) / float(w)
		var bbh := float(maxy - miny + 1) / float(h)
		if bbw > DEGEN_MAX_BBOX and bbh > DEGEN_MAX_BBOX:
			degen = "bbox-fills-canvas"

	return {
		"name": name, "w": w, "h": h, "edge": edge, "fill": fill,
		"green": green, "half_sides": half_sides, "degen": degen, "dup_of": ""
	}

func _verdict(r: Dictionary) -> String:
	var parts := []
	if r.half_sides.size() > 0:
		parts.append("HALF-CROP[%s]" % ",".join(r.half_sides))
	if r.green > GREEN_FRINGE_FLAG:
		parts.append("FRINGE")
	if r.degen != "":
		parts.append("DEGENERATE")
	if r.dup_of != "":
		parts.append("DUP-of-%s" % r.dup_of)
	if parts.is_empty():
		return "OK"
	return " ".join(parts)

func _signature(img: Image) -> PackedFloat32Array:
	var s := img.duplicate() as Image
	s.resize(16, 16, Image.INTERPOLATE_BILINEAR)
	var out := PackedFloat32Array()
	for y in 16:
		for x in 16:
			var c := s.get_pixel(x, y)
			out.append(c.a)
			out.append((c.r + c.g + c.b) / 3.0 * c.a)
	return out

func _sig_dist(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var sum := 0.0
	for i in a.size():
		var d := a[i] - b[i]
		sum += d * d
	return sqrt(sum / float(a.size()))

func _build_montage(files: Array) -> void:
	var scale := 2
	var cols := 7
	var cell_w := 0
	var cell_h := 0
	var imgs := {}
	for f in files:
		var img := Image.load_from_file(ProjectSettings.globalize_path("%s/%s" % [DIR, f]))
		if img == null:
			continue
		img.convert(Image.FORMAT_RGBA8)
		imgs[f] = img
		cell_w = max(cell_w, img.get_width())
		cell_h = max(cell_h, img.get_height())
	var pad := 8
	var label_h := 14
	var cw := cell_w * scale + pad * 2
	var ch := cell_h * scale + pad * 2 + label_h
	var rows := int(ceil(float(files.size()) / float(cols)))
	var out := Image.create(cw * cols, ch * rows, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.35, 0.35, 0.38))
	var idx := 0
	for f in files:
		var col := idx % cols
		var row := idx / cols
		var ox := col * cw + pad
		var oy := row * ch + pad + label_h
		# checker so transparency/fringe shows against bg
		if imgs.has(f):
			var im := imgs[f].duplicate() as Image
			im.resize(im.get_width() * scale, im.get_height() * scale, Image.INTERPOLATE_NEAREST)
			# center in cell
			var cx := ox + (cell_w * scale - im.get_width()) / 2
			var cy := oy + (cell_h * scale - im.get_height()) / 2
			out.blend_rect(im, Rect2i(0, 0, im.get_width(), im.get_height()), Vector2i(cx, cy))
		# draw label as tiny pixel index bar (name via simple markers) — draw a bright top strip
		var lbl_color := Color(0.9, 0.9, 0.2)
		for lx in range(col * cw + 2, col * cw + cw - 2):
			out.set_pixel(lx, row * ch + 2, lbl_color)
		idx += 1
	out.save_png(MONTAGE_OUT)
	print("")
	print("Montage saved: ", MONTAGE_OUT)
	print("Montage grid: %d cols x %d rows, cell %dx%d px, order = alpha-sorted filenames" % [cols, rows, cw, ch])
