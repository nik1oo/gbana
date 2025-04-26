package gbana


// CLOCK //
Clock:: struct {
	using interface: Clock_Interface }
clock: ^Clock
init_clock:: proc() {
	clock = new(Clock)
	init_clock_interface() }


// INTERFACE //
Clock_Interface:: struct {
	main_clock:                     ^Line,                    // MCLK
	wait:                           ^Line }                   // WAIT
init_clock_interface:: proc() {
	clock.main_clock = &gba_core.main_clock
	clock.wait = &gba_core.wait }