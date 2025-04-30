package gbana
import "core:container/queue"


HIGH:: true
LOW:: false
signals: [dynamic]Any_Signal
Any_Signal:: union{ ^Signal(u32), ^Signal(uint), ^Signal(u8), ^Signal(bool), ^Signal(GBA_Processor_Mode), ^Signal(GBA_Read_Write) }


// SIGNAL //
// TODO Add the ability to link two buses together, to create a bidirectional bus. Each bus object is stored in the component that it outputs to, and bidirectional buses are stored in both components and linked. //
Signal:: struct($T: typeid) {
	enabled:     bool,
	output:      T,
	_queue:      queue.Queue(Signal_Data(T)),
	latency:     int,
	write_phase: bit_set[0..=1],
	callback:    proc(self: ^Signal(T), new_output: T) }
signals_tick:: proc() {
	for signal in signals do #partial switch v in signal {
	case ^Signal(u32):                signal_tick(v)
	case ^Signal(uint):               signal_tick(v)
	case ^Signal(u8):                 signal_tick(v)
	case ^Signal(bool):               signal_tick(v)
	case ^Signal(GBA_Processor_Mode): signal_tick(v) } }
Signal_Data:: struct($T: typeid) {
	data:    T,
	latency: int }
signal_init:: proc(signal: ^Signal($T), latency: int = 1, callback: proc(self: ^Signal(T), new_output: T) = nil, enabled: bool = true, write_phase: bit_set[0..=1] = { LOW_PHASE, HIGH_PHASE }) {
	signal.enabled  = enabled
	signal.output   = {}
	signal.latency  = latency
	signal.callback = callback
	append_elem(&signals, signal) }
signal_put:: proc(signal: ^Signal($T), data: T, latency_override: int = -1) {
	queue.push_front(&signal._queue, Signal_Data(T) { data = data, latency = (latency_override == -1) ? (signal.latency - 1) : latency_override }) }
signal_force:: proc(signal: ^Signal($T), data: T) {
	signal.output = data
	signal._queue = {} }
signal_delay:: proc(signal: ^Signal($T), n: int) {
	for i in 0 ..< queue.len(signal._queue) {
		signal_data: = queue.get_ptr(&signal._queue, i)
		signal_data.latency += n } }
signal_tick:: proc(signal: ^Signal($T)) {
	for queue.len(signal._queue) > 0 {
		signal_data: = queue.back(&signal._queue)
		if signal_data.latency == 0 {
			assert(int(phase_index) in signal.write_phase)
			old_output: = signal.output
			signal.output = signal_data.data
			if (signal.output != old_output) && (signal.callback != nil) do signal.callback(signal, signal.output)
			queue.consume_back(&signal._queue, 1) }
		else do break }
	for i in 0 ..< queue.len(signal._queue) {
		signal_data: = queue.get_ptr(&signal._queue, i)
		signal_data.latency -= 1 } }