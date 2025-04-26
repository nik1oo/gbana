package gbana


GBA:: struct {
	gba_core:  GBA_Core,
	gb_core:   GB_Core,
	memory:    Memory,
	display:   Display,
	buttons:   Buttons,
	cartridge: Cartridge,
	speaker:   Speaker }
gba: ^GBA
init_gba:: proc() {
	gba = new(GBA)
	init_memory(&gba.memory)
	init_gba_core(&gba.gba_core)
	init_gb_core(&gba.gb_core)
	init_display(&gba.display)
	init_buttons(&gba.buttons)
	init_cartridge(&gba.cartridge)
	init_speaker(&gba.speaker) }