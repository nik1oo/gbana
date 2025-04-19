package gbana


// REGISTERS //
IE:: bit_field u16 {
	lcd_v_blank:          bool | 1,
	lcd_h_blank:          bool | 1,
	lcd_v_counter_match:  bool | 1,
	timer_0_overflow:     bool | 1,
	timer_1_overflow:     bool | 1,
	timer_2_overflow:     bool | 1,
	timer_3_overflow:     bool | 1,
	serial_communication: bool | 1,
	dma_0:                bool | 1,
	dma_1:                bool | 1,
	dma_2:                bool | 1,
	dma_3:                bool | 1,
	keypad:               bool | 1,
	game_pak:             bool | 1,
	_:                    int  | 2 }
IF:: bit_field u16 {
	lcd_v_blank:          bool | 1,
	lcd_h_blank:          bool | 1,
	lcd_v_counter_match:  bool | 1,
	timer_0_overflow:     bool | 1,
	timer_1_overflow:     bool | 1,
	timer_2_overflow:     bool | 1,
	timer_3_overflow:     bool | 1,
	serial_communication: bool | 1,
	dma_0:                bool | 1,
	dma_1:                bool | 1,
	dma_2:                bool | 1,
	dma_3:                bool | 1,
	keypad:               bool | 1,
	game_pak:             bool | 1,
	_:                    int  | 2 }
WAITCNT:: bit_field u32 {
	sram_wait_control:          enum { Cycles_4, Cycles_3, Cycles_2, Cycles_8 } | 2,
	wait_state_0_first_access:  enum { Cycles_4, Cycles_3, Cycles_2, Cycles_8 } | 2,
	wait_state_0_second_access: enum { Cycles_2, Cycles_1 }                     | 1,
	wait_state_1_first_access:  enum { Cycles_4, Cycles_3, Cycles_2, Cycles_8 } | 2,
	wait_state_1_second_access: enum { Cycles_4, Cycles_1 }                     | 1,
	wait_state_2_first_access:  enum { Cycles_4, Cycles_3, Cycles_2, Cycles_8 } | 2,
	wait_state_2_second_access: enum { Cycles_8, Cycles_1 }                     | 1,
	phi_terminal_output:        enum { Disable, MHz_4_19, MHz_8_38, MHz_16_78 } | 2,
	_:                          int                                             | 1,
	game_pak_prefetch_buffer:   bool                                            | 1,
	game_pak_type_flag:         enum { GBA, CGB }                               | 1,
	_:                          int                                             | 16 }
IME:: bit_field u32 {
  disable_all_interrupts: enum { Disable_All, Dont_Disable_All } | 1,
  _:                      int                                    | 31 }
POSTFLG:: bit_field u8 {
	subsequent_reset_flag: bool | 1,
	_:                     int  | 7 }
HALTCNT:: bit_field u8 {
	_:                   int                 | 7,
	battery_saving_mode: enum { Halt, Stop } | 1 }
UNDOCUMENTED_0x4000800:: bit_field u32 {
	Disable_WRAM:           bool | 1,
	_:                      int  | 2,
	Disable_CGB_Bootrom:    bool | 1,
	_:                      int  | 1,
	Enable_256K_WRAM:       bool | 1,
	_:                      int  | 18,
	Wait_Control_256K_WRAM: uint | 4,
	_:                      int  | 4 }