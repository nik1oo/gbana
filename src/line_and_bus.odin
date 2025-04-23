package gbana
import "core:container/queue"


// LINE //
Line:: Bus(bool)
Line_Value:: Bus_Data(bool)
line_put:: bus_put
line_tick:: bus_tick
line_init:: proc(line: ^Line, latency: int = 1, callback: proc(self: ^Line, new_output: bool) = nil) {
	bus_init(line, latency, callback) }


// BUS //
Bus:: struct($T: typeid) {
	output:  T,
	_queue:  queue.Queue(Bus_Data(T)),
	latency: int,
	callback: proc(self: ^Bus(T), new_output: T) }
Bus_Data:: struct($T: typeid) {
	data:    T,
	latency: int }
bus_init:: proc(bus: ^Bus($T), latency: int = 1, callback: proc(self: ^Bus(T), new_output: T) = nil) {
	bus.output = {}
	bus.latency = latency
	bus.callback = callback }
bus_put:: proc(bus: ^Bus($T), data: T, latency_override: int = -1) {
	queue.push_front(&bus._queue, Bus_Data(T) { data = data, latency = (latency_override == -1) ? (bus.latency - 1) : latency_override }) }
bus_force:: proc(bus: ^Bus($T), data: T) {
	bus.output = data
	bus.queue = {} }
bus_tick:: proc(bus: ^Bus($T)) {
	for queue.len(bus._queue) > 0 {
		bus_data: = queue.back(&bus._queue)
		if bus_data.latency == 0 {
			old_output: = bus.output
			bus.output = bus_data.data
			if (bus.output != old_output) && (bus.callback != nil) do bus.callback(bus, bus.output)
			queue.consume_back(&bus._queue, 1) }
		else do break }
	for i in 0 ..< queue.len(bus._queue) {
		bus_data: = queue.get_ptr(&bus._queue, i)
		bus_data.latency -= 1 } }