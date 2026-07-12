extends Node
## Audio removed per request. This stub keeps the Sfx autoload API intact
## so every call site still resolves — nothing plays. When we do sound properly
## later, back these methods with real players again.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func play(_sname: String, _db := -8.0, _pitch := 1.0) -> void:
	pass


func laser_on(_on: bool) -> void:
	pass


func thrust_on(_on: bool) -> void:
	pass


func klaxon_on(_on: bool) -> void:
	pass


func stop_loops() -> void:
	pass
