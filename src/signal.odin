package gbana
import "core:fmt"
import "core:container/queue"
import "core:log"


HIGH:: true
LOW:: false
READ:: HIGH
WRITE:: LOW
Any_Signal:: union{ ^Signal(u32), ^Signal(uint), ^Signal(u8), ^Signal(bool), ^Signal(GBA_Processor_Mode), ^Signal(GBA_Read_Write) }


// @(init) _:: proc() {
// 	signals = make([dynamic]Any_Signal) }


// SIGNAL //
// TODO Add the ability to link two buses together, to create a bidirectional bus. Each bus object is stored in the component that it outputs to, and bidirectional buses are stored in both components and linked. //
Signal:: struct($T: typeid) {
	name:        string,
	enabled:     bool,
	output:      T,
	_queue:      queue.Queue(Signal_Data(T)),
	latency:     int,
	write_phase: bit_set[0..=1],
	callback:    proc(self: ^Signal(T), new_output: T) }
signals_tick:: proc(current_tick_index:  uint, current_cycle_index: uint, current_phase_index: uint) {
	using state: ^State = cast(^State)context.user_ptr
	timeline_append(current_tick_index, current_cycle_index, current_phase_index)
	for signal in signals do #partial switch v in signal {
	case ^Signal(u32):                signal_tick(v)
	case ^Signal(uint):               signal_tick(v)
	case ^Signal(u8):                 signal_tick(v)
	case ^Signal(bool):               signal_tick(v)
	case ^Signal(GBA_Processor_Mode): signal_tick(v) } }
Signal_Data:: struct($T: typeid) {
	data:    T,
	latency: int }
signal_init:: proc(name: string, signal: ^Signal($T), latency: int = 1, callback: proc(self: ^Signal(T), new_output: T) = nil, enabled: bool = true, write_phase: bit_set[0..=1] = { LOW_PHASE, HIGH_PHASE }, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	if signal == nil do log.fatal("Signal is nil.", location = loc)
	signal.name        = name
	signal.enabled     = enabled
	signal.output      = {}
	signal.latency     = latency
	signal.callback    = callback
	signal.write_phase = write_phase
	append_elem(&signals, signal) }
signal_put:: proc(signal: ^Signal($T), data: T, latency_override: int = -1, loc: = #caller_location) {
	if signal == nil do log.fatal("Signal is nil.", location = loc)
	// fmt.println("Put", data, "on signal", signal.name, "at", loc)
	queue.push_front(&signal._queue, Signal_Data(T) { data = data, latency = (latency_override == -1) ? (signal.latency - 1) : (latency_override - 1) }) }
signal_force:: proc(signal: ^Signal($T), data: T) {
	signal.output = data
	signal._queue = {} }
signal_delay:: proc(signal: ^Signal($T), n: int) {
	for i in 0 ..< queue.len(signal._queue) {
		signal_data: = queue.get_ptr(&signal._queue, i)
		signal_data.latency += n } }
signal_tick:: proc(signal: ^Signal($T), loc: = #caller_location) {
	// log.info("Ticking signal", signal.name)
	if signal == nil do log.fatal("Signal is nil.", location = loc)
	using state: ^State = cast(^State)context.user_ptr
	for queue.len(signal._queue) > 0 {
		signal_data: = queue.back(&signal._queue)
		if signal_data.latency == 0 {
			if int(phase_index) not_in signal.write_phase do log.error("Attempted to update signal ", signal.name, " during phase ", phase_index, " but it is only allowed to be updated during phases ", signal.write_phase, ".", sep = "", location = loc)
			old_output: = signal.output
			signal.output = signal_data.data
			if (signal.output != old_output) && (signal.callback != nil) do signal.callback(signal, signal.output)
			queue.consume_back(&signal._queue, 1) }
		else do break }
	for i in 0 ..< queue.len(signal._queue) {
		signal_data: = queue.get_ptr(&signal._queue, i)
		signal_data.latency -= 1
		// fmt.println("signal", signal.name, "ticks down to", signal_data.latency)
} }
signal_stub_callback:: proc(self: ^Signal(bool), new_output: bool) { }