package gbana


TICKS:: #force_inline proc($tick: int) -> (ticks: int) { return ticks }
CYCLES:: #force_inline proc($ticks: int) -> (cycles: int) { return 2 * ticks }


// CLOCK //
Clock:: struct {
	using interface: Clock_Interface }
clock: ^Clock
init_clock:: proc() {
	clock = new(Clock)
	init_clock_interface() }


// INTERFACE //
Clock_Interface:: struct {
	main_clock:                     ^Signal(bool),                    // MCLK
	wait:                           ^Signal(bool) }                   // WAIT
init_clock_interface:: proc() {
	using state: ^State = cast(^State)context.user_ptr
	clock.main_clock = &gba_core.main_clock
	clock.wait = &gba_core.wait }