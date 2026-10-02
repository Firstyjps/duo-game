extends RefCounted

func test_event_bus_emits() -> bool:
	var bus: Node = load("res://core/event_bus.gd").new()
	var got: Array[int] = []
	bus.example_ping.connect(func(v: int) -> void: got.append(v))
	bus.example_ping.emit(7)
	bus.free()
	return got == [7]
