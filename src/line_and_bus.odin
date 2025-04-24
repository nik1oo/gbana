package gbana
import "core:container/queue"


// LINE //
Line:: Bus(bool)
Line_Value:: Bus_Data(bool)
line_put:: bus_put
line_force:: bus_force
line_delay:: bus_delay
line_tick:: bus_tick
line_init:: proc(line: ^Line, latency: int = 1, callback: proc(self: ^Line, new_output: bool) = nil, enabled: bool = true) {
	bus_init(line, latency, callback, enabled) }


// BUS //
// TODO Add the ability to link two buses together, to create a bidirectional bus. Each bus object is stored in the component that it outputs to, and bidirectional buses are stored in both components and linked. //
Bus:: struct($T: typeid) {
	enabled:  bool,
	output:   T,
	_queue:   queue.Queue(Bus_Data(T)),
	latency:  int,
	callback: proc(self: ^Bus(T), new_output: T) }
Bus_Data:: struct($T: typeid) {
	data:    T,
	latency: int }
bus_init:: proc(bus: ^Bus($T), latency: int = 1, callback: proc(self: ^Bus(T), new_output: T) = nil, enabled: bool = true) {
	bus.enabled  = enabled
	bus.output   = {}
	bus.latency  = latency
	bus.callback = callback }
bus_put:: proc(bus: ^Bus($T), data: T, latency_override: int = -1) {
	queue.push_front(&bus._queue, Bus_Data(T) { data = data, latency = (latency_override == -1) ? (bus.latency - 1) : latency_override }) }
bus_force:: proc(bus: ^Bus($T), data: T) {
	bus.output = data
	bus._queue  = {} }
bus_delay:: proc(bus: ^Bus($T), n: int) {
	for i in 0 ..< queue.len(bus._queue) {
		bus_data: = queue.get_ptr(&bus._queue, i)
		bus_data.latency += n } }
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