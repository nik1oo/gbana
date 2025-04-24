package gbana


// CLOCK //
Clock:: struct {
	interface:
}
clock: ^Clock
init_clock:: proc() {
	// Interface //
	clock = new(Clock)


// INTERFACE //
Clock_Interface:: struct {
	using _: struct #raw_union { MCLK:    ^Line,                    main_clock:                     ^Line                    },
	using _: struct #raw_union { WAIT:    ^Line,                    wait:                           ^Line                    } }
init_clock_interface:: proc() {
	clock.MCLK = &gba_core.MCLK
	clock.WAIT = &gba_core.WAIT }