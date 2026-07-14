extends SceneTree
## CROP-QA inspector for crew / walk / trash sprite sets. INSPECTION ONLY.
## Per-file edge-opacity + green-residue flags, per-set size-uniformity check,
## and a labelled montage per set. Mirrors tools/inspect_trash.gd's approach.

const OUT_DIR := "C:/Users/menel/AppData/Local/Temp/claude/C--Users-menel-OneDrive---------games-spacewalker-godot47/7e4ea51e-90ff-4cf5-a9f6-830ffa3aca60/scratchpad"

const EDGE_OPAQUE_FLAG := 0.18
const ALPHA_OPAQUE := 0.5
const GREEN_FRINGE_FLAG := 40
const DEGEN_MIN_FILL := 0.004

func _init() -> void:
	var sets := [
		{"name": "crew_main", "dir": "res://assets/sprites/crew", "sub": ""},
		{"name": "crew_dialog", "dir": "res://assets/sprites/crew/dialog", "sub": ""},
		{"name": "crew_idle", "dir": "res://assets/sprites/crew/idle", "sub": ""},
		{"name": "crew_roster", "dir": "res://assets/sprites/crew/roster", "sub": ""},
		{"name": "walk", "dir": "res://assets/sprites/walk", "sub": ""},
		{"name": "trash", "dir": "res://assets/sprites/trash", "sub": ""},
	]
	for s in sets:
		_do_set(s.name, s.dir)
	quit(0)

func _do_set(set_name: String, dir: String) -> void:
	var files := _list_pngs(dir)
	print("")
	print("############## SET: %s  (%s)  %d files ##############" % [set_name, dir, files.size()])
	if files.is_empty():
		print("  (no pngs)")
		return
	var records := []
	# group -> [ [w,h], ... ]  where group is filename minus trailing _<digits>
	var groups := {}
	for f in files:
		var img := Image.load_from_file(ProjectSettings.globalize_path("%s/%s" % [dir, f]))
		if img == null:
			print("LOAD-FAIL ", f)
			continue
		img.convert(Image.FORMAT_RGBA8)
		var rec := _analyze(img, f)
		records.append(rec)
		var g := _group_of(f)
		if not groups.has(g):
			groups[g] = []
		groups[g].append([rec.w, rec.h, f])

	print("file                  | size     | eL   eR   eT   eB   | fill%% | green | verdict")
	print("----------------------+----------+---------------------+-------+-------+-----------------")
	var flagged := []
	for r in records:
		var verdict := _verdict(r)
		if verdict != "OK":
			flagged.append("%s/%s : %s" % [set_name, r.name, verdict])
		print("%-21s | %4dx%-4d| %4.0f %4.0f %4.0f %4.0f | %4.1f%% | %5d | %s" % [
			r.name, r.w, r.h,
			r.edge[0] * 100.0, r.edge[1] * 100.0, r.edge[2] * 100.0, r.edge[3] * 100.0,
			r.fill * 100.0, r.green, verdict])

	# size-uniformity per group (frames of one direction / one crew idle must match)
	print("  --- size uniformity per group ---")
	for g in groups.keys():
		var arr = groups[g]
		if arr.size() < 2:
			continue
		var w0 = arr[0][0]
		var h0 = arr[0][1]
		var uniform := true
		for e in arr:
			if e[0] != w0 or e[1] != h0:
				uniform = false
		if uniform:
			print("    [OK]   %-14s %d frames all %dx%d" % [g, arr.size(), w0, h0])
		else:
			var detail := ""
			for e in arr:
				detail += "%s=%dx%d " % [e[2], e[0], e[1]]
			print("    [VARY] %-14s : %s" % [g, detail])
			flagged.append("%s/%s : SIZE-MISMATCH within set (%s)" % [set_name, g, detail])

	print("  --- FLAGS for %s (%d) ---" % [set_name, flagged.size()])
	for s in flagged:
		print("    ", s)
	_build_montage(set_name, dir, files)

func _group_of(f: String) -> String:
	var base := f.get_basename()
	var parts := base.split("_")
	# drop a trailing pure-number token (frame index) so front_0..7 -> front
	if parts.size() > 1 and parts[parts.size() - 1].is_valid_int():
		parts.remove_at(parts.size() - 1)
		return "_".join(parts)
	return base

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
	out.sort()
	return out

func _analyze(img: Image, name: String) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
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
			# green-screen residue: greenish, semi-opaque
			if c.a > 0.2 and c.g > 0.35 and c.g > c.r * 1.25 and c.g > c.b * 1.25:
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

	# whitespace / loose trim: how much margin around the opaque bbox
	var trim := ""
	if maxx >= 0:
		var mL := float(minx) / float(w)
		var mR := float(w - 1 - maxx) / float(w)
		var mT := float(miny) / float(h)
		var mB := float(h - 1 - maxy) / float(h)
		var maxm = max(max(mL, mR), max(mT, mB))
		if maxm > 0.22:
			trim = "loose-trim(%d%%)" % int(maxm * 100.0)

	return {
		"name": name, "w": w, "h": h, "edge": edge, "fill": fill,
		"green": green, "half_sides": half_sides, "degen": degen, "trim": trim
	}

func _verdict(r: Dictionary) -> String:
	var parts := []
	if r.half_sides.size() > 0:
		parts.append("EDGE-CLIP[%s]" % ",".join(r.half_sides))
	if r.green > GREEN_FRINGE_FLAG:
		parts.append("GREEN(%d)" % r.green)
	if r.degen != "":
		parts.append("DEGENERATE")
	if r.trim != "":
		parts.append(r.trim)
	if parts.is_empty():
		return "OK"
	return " ".join(parts)

func _build_montage(set_name: String, dir: String, files: Array) -> void:
	var scale := 1
	var cols := 10
	if files.size() <= 40:
		scale = 2
		cols = 6
	var cell_w := 0
	var cell_h := 0
	var imgs := {}
	for f in files:
		var img := Image.load_from_file(ProjectSettings.globalize_path("%s/%s" % [dir, f]))
		if img == null:
			continue
		img.convert(Image.FORMAT_RGBA8)
		imgs[f] = img
		cell_w = max(cell_w, img.get_width())
		cell_h = max(cell_h, img.get_height())
	# cap oversized cells
	var maxcell := 220
	var dscale := 1.0
	if cell_w * scale > maxcell or cell_h * scale > maxcell:
		dscale = float(maxcell) / float(max(cell_w, cell_h) * scale)
	var draw_w := int(cell_w * scale * dscale)
	var draw_h := int(cell_h * scale * dscale)
	var pad := 6
	var label_h := 10
	var cw := draw_w + pad * 2
	var ch := draw_h + pad * 2 + label_h
	var rows := int(ceil(float(files.size()) / float(cols)))
	var out := Image.create(cw * cols, ch * rows, false, Image.FORMAT_RGBA8)
	# magenta checker background so any green fringe / clip stands out
	for y in out.get_height():
		for x in out.get_width():
			var chk := ((x / 8) + (y / 8)) % 2 == 0
			out.set_pixel(x, y, Color(0.65, 0.1, 0.65) if chk else Color(0.5, 0.08, 0.5))
	var idx := 0
	for f in files:
		var col := idx % cols
		var row := idx / cols
		var ox := col * cw + pad
		var oy := row * ch + pad + label_h
		if imgs.has(f):
			var im := imgs[f].duplicate() as Image
			var nw = max(1, int(im.get_width() * scale * dscale))
			var nh = max(1, int(im.get_height() * scale * dscale))
			im.resize(nw, nh, Image.INTERPOLATE_NEAREST)
			var cx := ox + (draw_w - im.get_width()) / 2
			var cy := oy + (draw_h - im.get_height()) / 2
			out.blend_rect(im, Rect2i(0, 0, im.get_width(), im.get_height()), Vector2i(cx, cy))
		for lx in range(col * cw + 2, col * cw + cw - 2):
			out.set_pixel(lx, row * ch + 2, Color(1, 1, 0.2))
		idx += 1
	var path := "%s/insp_%s.png" % [OUT_DIR, set_name]
	out.save_png(path)
	print("  montage -> ", path, "  (%d cols x %d rows, order=alpha)" % [cols, rows])
