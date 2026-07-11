extends Node
## Sfx (autoload) — every sound in the game, synthesized at boot.
## No audio assets: sine/square/noise generators build AudioStreamWAVs
## in ~50ms. One pool for one-shots, dedicated players for loops.

const RATE := 22050

var _s := {}                              # name -> AudioStreamWAV
var _pool: Array[AudioStreamPlayer] = []
var _laser: AudioStreamPlayer
var _thrust: AudioStreamPlayer
var _klaxon: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_all()
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_laser = _make_loop_player("laser", -24.0)
	_thrust = _make_loop_player("thrust", -20.0)
	_klaxon = _make_loop_player("klaxon", -14.0)


func _make_loop_player(sname: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = _s[sname]
	p.volume_db = db
	add_child(p)
	return p


func play(sname: String, db := -8.0, pitch := 1.0) -> void:
	for p in _pool:
		if not p.playing:
			p.stream = _s[sname]
			p.volume_db = db
			p.pitch_scale = pitch
			p.play()
			return


func laser_on(on: bool) -> void:
	if on and not _laser.playing:
		_laser.play()
	elif not on and _laser.playing:
		_laser.stop()


func thrust_on(on: bool) -> void:
	if on and not _thrust.playing:
		_thrust.play()
	elif not on and _thrust.playing:
		_thrust.stop()


func klaxon_on(on: bool) -> void:
	if on and not _klaxon.playing:
		_klaxon.play()
	elif not on and _klaxon.playing:
		_klaxon.stop()


func stop_loops() -> void:
	laser_on(false)
	thrust_on(false)
	klaxon_on(false)


# ------------------------------------------------------------------
# Synthesis
# ------------------------------------------------------------------
func _wav(samples: PackedFloat32Array, looped := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if looped:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = samples.size()
	return w


func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


## Sound design v2 — everything soft, warm and musical. Rules:
##  - NO square waves, ever: pure sine stacks with 2-3 gentle harmonics.
##  - every one-shot opens with a 6-10ms attack ramp (no clicks) and dies
##    on an EXPONENTIAL tail (struck objects, not gated buzzers).
##  - noise is always run through a heavy one-pole lowpass (dark rumble
##    and air, never white hiss).
##  - loops are seam-free: sine parts use whole cycles per buffer, noise
##    parts get a crossfaded tail.
func _note(buf: PackedFloat32Array, start: float, f: float, amp: float,
		decay: float) -> void:
	## A soft bell note added INTO the buffer: fundamental + quiet octave
	## + whisper of the 12th, exponential tail, 8ms attack.
	var i0 := int(start * RATE)
	for i in range(i0, buf.size()):
		var t := float(i - i0) / RATE
		var env := minf(t / 0.008, 1.0) * exp(-t / decay)
		if env < 0.001:
			break
		buf[i] += (sin(TAU * f * t) \
			+ 0.35 * sin(TAU * f * 2.0 * t) \
			+ 0.12 * sin(TAU * f * 3.0 * t)) * amp * env


func _lp_noise(rng: RandomNumberGenerator, n: int, cutoff: float) -> PackedFloat32Array:
	## One-pole lowpassed noise, normalized-ish. Small cutoff = dark rumble.
	var out := PackedFloat32Array()
	out.resize(n)
	var prev := 0.0
	for i in n:
		prev = lerpf(prev, rng.randf() * 2.0 - 1.0, cutoff)
		out[i] = prev
	return out


func _crossfade_loop(buf: PackedFloat32Array, fade: int) -> PackedFloat32Array:
	## Blend the head into the tail so a noise loop has no seam. The buffer
	## must be generated `fade` samples LONGER than the wanted loop.
	var n := buf.size() - fade
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		if i < fade:
			out[i] = lerpf(buf[n + i], buf[i], float(i) / fade)
		else:
			out[i] = buf[i]
	return out


func _build_all() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242

	# mining laser — a warm, low power-hum (loop, whole cycles only).
	# 110Hz bed + a fifth above it, slow 5Hz shimmer. Feels like energy,
	# not like a dentist drill.
	var laser := _buf(0.6)
	for i in laser.size():
		var t := float(i) / RATE
		var trem := 0.85 + 0.15 * sin(TAU * 5.0 * t)
		laser[i] = (sin(TAU * 110.0 * t) * 0.45 + sin(TAU * 165.0 * t) * 0.25 \
			+ sin(TAU * 440.0 * t) * 0.06) * trem * 0.6
	_s["laser"] = _wav(laser, true)

	# thrusters — a deep, dark rumble: heavily lowpassed noise over a
	# 55Hz bed, tail crossfaded so the loop never pops
	var fade := int(0.15 * RATE)
	var thn := _lp_noise(rng, int(0.8 * RATE) + fade, 0.06)
	var th := _crossfade_loop(thn, fade)
	for i in th.size():
		var t := float(i) / RATE
		th[i] = th[i] * 0.55 + sin(TAU * 55.0 * t) * 0.18
	_s["thrust"] = _wav(th, true)

	# flare klaxon — a mellow rise-and-fall "whoop", not an angry buzzer.
	# Sine sweep 380->560->380 with a silence-kissed envelope (loop-safe).
	var kl := _buf(1.6)
	var ph := 0.0
	for i in kl.size():
		var t := float(i) / RATE
		var sweep := 0.5 - 0.5 * cos(TAU * t / 1.6)      # 0..1..0
		ph += TAU * (380.0 + 180.0 * sweep) / RATE
		var env := pow(sin(PI * t / 1.6), 0.7)           # silent at both ends
		kl[i] = sin(ph) * 0.4 * env
	_s["klaxon"] = _wav(kl, true)

	# ore pickup — a tiny glass plink (played with random pitch already)
	var pk := _buf(0.22)
	_note(pk, 0.0, 880.0, 0.4, 0.05)
	_s["pickup"] = _wav(pk)

	# banked / paid — two warm marimba notes, tails overlapping (C5 → G5)
	var bk := _buf(0.6)
	_note(bk, 0.0, 523.25, 0.34, 0.1)
	_note(bk, 0.12, 784.0, 0.3, 0.14)
	_s["bank"] = _wav(bk)

	# upgrade / craft / rescue — a gentle four-note bell arpeggio
	# (C5 E5 G5 C6), each note ringing into the next
	var up := _buf(0.9)
	_note(up, 0.0, 523.25, 0.26, 0.09)
	_note(up, 0.09, 659.25, 0.26, 0.09)
	_note(up, 0.18, 784.0, 0.26, 0.1)
	_note(up, 0.27, 1046.5, 0.3, 0.16)
	_s["upgrade"] = _wav(up)

	# denied — two soft low taps, a polite "uh-uh" (no buzz)
	var dn := _buf(0.3)
	_note(dn, 0.0, 196.0, 0.4, 0.045)
	_note(dn, 0.11, 155.6, 0.42, 0.06)
	_s["deny"] = _wav(dn)

	# debris thud / blackout — a felt impact: pitch-dropping sine body
	# with a dark noise puff, all on an exponential tail
	var td := _buf(0.4)
	var tdn := _lp_noise(rng, td.size(), 0.12)
	var phd := 0.0
	for i in td.size():
		var t := float(i) / RATE
		phd += TAU * (85.0 * exp(-t * 3.0) + 38.0) / RATE
		var env := minf(t / 0.006, 1.0) * exp(-t / 0.11)
		td[i] = (sin(phd) * 0.62 + tdn[i] * 0.3) * env
	_s["thud"] = _wav(td)

	# tether clack — one clean metallic tick, tiny and precise
	var ck := _buf(0.12)
	var ckn := _lp_noise(rng, ck.size(), 0.5)
	_note(ck, 0.0, 1175.0, 0.2, 0.02)
	for i in ck.size():
		var t := float(i) / RATE
		ck[i] += ckn[i] * 0.22 * minf(t / 0.002, 1.0) * exp(-t / 0.012)
	_s["clack"] = _wav(ck)

	# O2 low — two mellow, rounded beeps (sine-squared edges, no shrill)
	var o2 := _buf(0.6)
	for i in o2.size():
		var t := float(i) / RATE
		var seg := fmod(t, 0.3)
		if seg < 0.14:
			var w := sin(PI * seg / 0.14)
			o2[i] = sin(TAU * 660.0 * t) * 0.35 * w * w
	_s["o2low"] = _wav(o2)

	# canister hiss — soft dark air, a relief not a leak
	var hs := _lp_noise(rng, int(0.5 * RATE), 0.3)
	for i in hs.size():
		var t := float(i) / RATE
		hs[i] *= minf(t / 0.02, 1.0) * exp(-t / 0.16) * 0.5
	_s["hiss"] = _wav(hs)

	# interior footstep — a barely-there soft pad on the deck
	var st := _lp_noise(rng, int(0.08 * RATE), 0.18)
	for i in st.size():
		var t := float(i) / RATE
		st[i] *= minf(t / 0.004, 1.0) * exp(-t / 0.022) * 0.5
	_s["step"] = _wav(st)

	# radio — a warm little two-tone chirp, like a friendly comm handshake
	var rd := _buf(0.4)
	_note(rd, 0.0, 740.0, 0.22, 0.05)
	_note(rd, 0.1, 988.0, 0.22, 0.09)
	_s["radio"] = _wav(rd)
