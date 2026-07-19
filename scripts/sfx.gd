extends Node
## Real SFX (autoload "Sfx"). Loads every mp3 in res://assets/audio/ by filename,
## plays one-shots from a small round-robin pool, manages dedicated LOOP players
## (laser / thrust / klaxon) and a crossfading AMBIENT bed. Legacy call-site keys
## are aliased to files in ALIAS so old Sfx.play("bank"/"clack"/…) calls resolve.

const DIR := "res://assets/audio/"

# legacy call-keys used across the code -> the audio file that fits them
const ALIAS := {
	"bank": "trade_buy",       # depositing ore reads like a cash register
	"clack": "tether_clack",
	"radio": "crew_greet",     # beacon / dialog chatter
	"thud": "debris_thud",
	"upgrade": "upgrade_purchased",
}

var _streams := {}          # basename -> AudioStream
var _pool: Array = []       # one-shot AudioStreamPlayers
var _pool_i := 0
var _laser: AudioStreamPlayer
var _thrust: AudioStreamPlayer
var _klaxon: AudioStreamPlayer
var _amb: AudioStreamPlayer
var _amb_name := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var d := DirAccess.open(DIR)
	if d != null:
		for f in d.get_files():
			if f.ends_with(".mp3"):
				var s: AudioStream = load(DIR + f)
				if s != null:
					_streams[f.get_basename()] = s
	for _i in 8:
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_pool.append(p)
	_laser = _mk_loop("laser_loop", -6.0)
	_thrust = _mk_loop("thrust_loop", -8.0)
	_klaxon = _mk_loop("flare_klaxon", -4.0)
	_amb = _mk_loop("", -18.0)


func _mk_loop(sname: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.volume_db = db
	if sname != "" and _streams.has(sname):
		p.stream = _looped(_streams[sname])
	add_child(p)
	return p


func _looped(stream: AudioStream) -> AudioStream:
	# duplicate so toggling loop never mutates the shared one-shot copy
	var s: AudioStream = stream.duplicate()
	if s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	return s


func _resolve(sname: String) -> AudioStream:
	var key: String = ALIAS.get(sname, sname)
	return _streams.get(key, null)


func play(sname: String, db := -8.0, pitch := 1.0) -> void:
	var s := _resolve(sname)
	if s == null:
		return
	var p: AudioStreamPlayer = _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = s
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()


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


func ambient(sname: String) -> void:
	## Set the looping ambient bed for the current scene (crossfade-lite: just
	## swap; the bed is quiet enough that a hard cut is inaudible). "" = silence.
	if sname == _amb_name:
		return
	_amb_name = sname
	if sname != "" and _streams.has(sname):
		_amb.stream = _looped(_streams[sname])
		_amb.play()
	else:
		_amb.stop()


func stop_loops() -> void:
	_laser.stop()
	_thrust.stop()
	_klaxon.stop()
