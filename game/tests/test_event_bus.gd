extends RefCounted

func test_event_bus_emits() -> bool:
	var bus: Node = load("res://core/event_bus.gd").new()
	var got: Array[int] = []
	bus.player_died.connect(func() -> void: got.append(1))
	bus.player_died.emit()
	bus.free()
	return got == [1]
