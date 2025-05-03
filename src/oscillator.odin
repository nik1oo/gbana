package gbana
import "core:thread"


Oscillator:: struct { }
initialize_oscillator:: proc() {
	using state: ^State = cast(^State)context.user_ptr }


TICKS:: #force_inline proc($tick: int) -> (ticks: int) { return ticks }
CYCLES:: #force_inline proc($ticks: int) -> (cycles: int) { return 2 * ticks }


falling_edge:: proc(old_output, new_output: bool) -> bool { return (old_output == HIGH) && (new_output == LOW) }
rising_edge::  proc(old_output, new_output: bool) -> bool { return (old_output == LOW)  && (new_output == HIGH) }
main_clock_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) {
	using state: ^State = cast(^State)context.user_ptr
	signal_put(self, ! new_output) }
	// switch {
	// case falling_edge(old_output, new_output):
	// 	if memory.sequential_cycle.output do switch memory.memory_access_size.output {
	// 	case Memory_Access_Size.BYTE:     signal_force(&memory.address, memory.address.output + 1)
	// 	case Memory_Access_Size.HALFWORD: signal_force(&memory.address, memory.address.output + 2)
	// 	case Memory_Access_Size.WORD:     signal_force(&memory.address, memory.address.output + 4) }
	// case rising_edge(old_output, new_output): } }


// THREAD //
oscillator_thread_proc:: proc(t: ^thread.Thread) { }