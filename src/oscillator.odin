package gbana


Oscillator:: struct { }
initialize_oscillator:: proc() {
	using state: ^State = cast(^State)context.user_ptr }


TICKS:: #force_inline proc($tick: int) -> (ticks: int) { return ticks }
CYCLES:: #force_inline proc($ticks: int) -> (cycles: int) { return 2 * ticks }