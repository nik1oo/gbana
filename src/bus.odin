package gbana


Bus_Data:: struct($WIDTH: int) {
	data:              [WIDTH]u8,
	latency: int }
Bus:: struct($WIDTH: int) {
	data_output: [WIDTH]u8,
	data_queue:  queue.Queue(Bus_Data(WIDTH)),
	latency:      int }


bus_init:: proc(bus: ^Bus($WIDTH), latency: int = 1) {
	bus.data_output = {}
	bus.latency = latency }
bus_put:: proc(bus: ^Bus($WIDTH), data: [WIDTH]u8) {
	queue.push_front(&bus.data_queue, Bus_Data(WIDTH) { data = data, latency = bus.latency - 1 }) }
bus_tick:: proc(bus: ^Bus($WIDTH)) {
	for queue.len(bus.data_queue) > 0 {
		bus_data: = queue.back(&bus.data_queue)
		if bus_data.latency == 0 {
			bus.data_output = bus_data.data
			queue.consume_back(&bus.data_queue, 1) }
		else do break }
	for i in 0 ..< queue.len(bus.data_queue) {
		bus_data: = queue.get_ptr(&bus.data_queue, i)
		bus_data.latency -= 1 } }