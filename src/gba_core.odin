#+feature dynamic-literals
package gbana
import "core:fmt"
import "core:container/queue"
import "core:math/bits"
import "core:math/rand"
import "core:encoding/endian"


ALU:: struct {

}


// INTERFACE //
// Reference: Figure 1-4 ARM7TDMI processor functional diagram //
// NOTE: A prefix of `n` before a signal means logical negation, eg nM is the negation of M. //
GBA_Core_Interface:: struct {
	// Clocks And Timing //
	main_clock:                     Line,                    // MCLK
	wait:                           Line,                    // WAIT
	// Interrupts //
	interrupt_request:              Line,                    // IRQ
	fast_interrupt_request:         Line,                    // FIQ
	synchronous_interrupts_enable:  Line,                    // ISYNC
	// Bus Controls //
	reset:                          Line,                    // RESET
	bus_enable:                     Line,                    // BUSEN
	big_endian:                     Line,                    // BIGEND
	input_enable:                   Line,                    // ENIN
	output_enable:                  Line,                    // ENOUT
	address_bus_enable:             Line,                    // ABE
	address_latch_enable:           Line,                    // ALE
	address_pipeline_enable:        Line,                    // APE
	op_code_fetch:                  Line,                    // OPC
	data_bus_enable:                Line,                    // DBE
	test_bus_enable:                Line,                    // TBE
	bus_disable:                    Line,                    // BUSDIS
	external_test_capture_clock:    Line,                    // ECAPCLK
	// Processor Mode //
	processor_mode:                 Bus(GBA_Processor_Mode), // M
	// Processor State //
	executing_thumb:                Line,                    // TBIT
	// Memory //
	addresses:                      Bus(u32),                // A
	data_output_bus:                Bus(u32),                // DOUT
	data_bus:                       Bus(u32),                // D
	data_input_bus:                 Bus(u32),                // DIN
	memory_request:                 Line,                    // MREQ
	sequential_cycle:               Line,                    // SEQ
	read_write:                     Line,                    // RW
	memory_access_size:             Bus(uint),               // MAS
	byte_latch_control:             Bus(u8),                 // BL
	locked_operation:               Line }                   // LOCK
init_gba_core_interface:: proc() {
	line_init(&gba_core.main_clock,    2, gba_main_clock_callback); line_put(&gba_core.main_clock, true)
	line_init(&gba_core.WAIT,    1, gba_WAIT_callback)
	line_init(&gba_core.IRQ,     1, gba_IRQ_callback)
	line_init(&gba_core.FIQ,     1, gba_FIQ_callback)
	line_init(&gba_core.ISYNC,   1, gba_ISYNC_callback)
	line_init(&gba_core.RESET,   1, gba_RESET_callback)
	line_init(&gba_core.BUSEN,   1, gba_BUSEN_callback)
	line_init(&gba_core.BIGEND,  1, gba_BIGEND_callback)
	line_init(&gba_core.ENIN,    1, gba_ENIN_callback)
	line_init(&gba_core.ENOUT,   1, gba_ENOUT_callback)
	line_init(&gba_core.ABE,     1, gba_ABE_callback)
	line_init(&gba_core.ALE,     1, gba_ALE_callback)
	line_init(&gba_core.APE,     1, gba_APE_callback)
	line_init(&gba_core.OPC,     1, gba_OPC_callback)
	line_init(&gba_core.DBE,     1, gba_DBE_callback)
	line_init(&gba_core.TBE,     1, gba_TBE_callback)
	line_init(&gba_core.BUSDIS,  1, gba_BUSDIS_callback)
	line_init(&gba_core.ECAPCLK, 1, gba_ECAPCLK_callback)
	bus_init(&gba_core.M,        1, gba_M_callback)
	line_init(&gba_core.TBIT,    1, gba_TBIT_callback)
	bus_init(&gba_core.A,        1, gba_A_callback)
	bus_init(&gba_core.DOUT,     1, gba_DOUT_callback)
	bus_init(&gba_core.D,        1, gba_D_callback)
	bus_init(&gba_core.DIN,      1, gba_DIN_callback)
	bus_init(&gba_core.MREQ,     1, gba_MREQ_callback)
	bus_init(&gba_core.sequential_cycle,      1, gba_sequential_cycle_callback)
	bus_init(&gba_core.RW,       1, gba_RW_callback)
	bus_init(&gba_core.MAS,      1, gba_MAS_callback)
	bus_init(&gba_core.BL,       1, gba_BL_callback)
	bus_init(&gba_core.LOCK,     1, gba_LOCK_callback) }
tick_gba_core_interface:: proc() {
	line_tick(&gba_core.main_clock)
	line_tick(&gba_core.WAIT)
	line_tick(&gba_core.IRQ)
	line_tick(&gba_core.FIQ)
	line_tick(&gba_core.ISYNC)
	line_tick(&gba_core.RESET)
	line_tick(&gba_core.BUSEN)
	line_tick(&gba_core.BIGEND)
	line_tick(&gba_core.ENIN)
	line_tick(&gba_core.ENOUT)
	line_tick(&gba_core.ABE)
	line_tick(&gba_core.ALE)
	line_tick(&gba_core.APE)
	line_tick(&gba_core.OPC)
	line_tick(&gba_core.DBE)
	line_tick(&gba_core.TBE)
	line_tick(&gba_core.BUSDIS)
	line_tick(&gba_core.ECAPCLK)
	bus_tick(&gba_core.M)
	line_tick(&gba_core.TBIT)
	bus_tick(&gba_core.A)
	bus_tick(&gba_core.DOUT)
	bus_tick(&gba_core.D)
	bus_tick(&gba_core.DIN)
	bus_tick(&gba_core.MREQ)
	bus_tick(&gba_core.sequential_cycle)
	bus_tick(&gba_core.RW)
	bus_tick(&gba_core.MAS)
	bus_tick(&gba_core.BL)
	bus_tick(&gba_core.LOCK) }


// SIGNALS //
HIGH:: true
LOW::  false
gba_watch_signals:: proc() {
	if gba_core_states[CURRENT_STATE].RESET.output != gba_core_states[PREVIOUS_STATE].RESET.output do gba_signal_callback_reset() }
gba_signal_callback_reset:: proc() {
	switch gba_core_states[CURRENT_STATE].RESET.output {
	case HIGH:
		for i in uint(GBA_Physical_Register_Name.R0) ..< uint(GBA_Physical_Register_Name.CPSR) do gba_core.physical_registers.array[i] = rand.uint32()
		// TODO More information is provided in Reset sequence after power up on page 3-33. //
	case LOW:
		gba_core.physical_registers.array[GBA_Physical_Register_Name.R14_SVC] = gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^
		gba_core.physical_registers.array[GBA_Physical_Register_Name.SPSR_SVC] = gba_core.logical_registers.array[GBA_Logical_Register_Name.CPSR]^
		bus_put(&gba_core.processor_mode, GBA_Processor_Mode.Supervisor)
		cpsr: = gba_get_cpsr()
		cpsr.irq_interrupt_disable = true
		cpsr.fiq_interrupt_disable = true
		cpsr.thumb_state = false
		gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^ = 0b0 } }
// NOTE Ignore the bounary-scan circuit stuff and the TAP controller. Those are for hardware circuit testing. //


// TODO 3-1 Memory Interface


// TIMING //
gba_insert_wait_cycle:: proc() {
	line_delay(&gba_core.main_clock, 2) }
gba_main_clock_callback::    proc(self: ^Line, new_output: bool) {
	line_put(self, ! new_output) }
gba_WAIT_callback::    proc(self: ^Line, new_output: bool) { }
gba_IRQ_callback::     proc(self: ^Line, new_output: bool) { }
gba_FIQ_callback::     proc(self: ^Line, new_output: bool) { }
gba_ISYNC_callback::   proc(self: ^Line, new_output: bool) { }
gba_RESET_callback::   proc(self: ^Line, new_output: bool) { }
gba_BUSEN_callback::   proc(self: ^Line, new_output: bool) { }
gba_BIGEND_callback::  proc(self: ^Line, new_output: bool) { }
gba_ENIN_callback::    proc(self: ^Line, new_output: bool) { }
gba_ENOUT_callback::   proc(self: ^Line, new_output: bool) { }
gba_ABE_callback::     proc(self: ^Line, new_output: bool) { }
gba_ALE_callback::     proc(self: ^Line, new_output: bool) { }
gba_APE_callback::     proc(self: ^Line, new_output: bool) { }
gba_OPC_callback::     proc(self: ^Line, new_output: bool) { }
gba_DBE_callback::     proc(self: ^Line, new_output: bool) { }
gba_TBE_callback::     proc(self: ^Line, new_output: bool) { }
gba_BUSDIS_callback::  proc(self: ^Line, new_output: bool) { }
gba_ECAPCLK_callback:: proc(self: ^Line, new_output: bool) { }
gba_M_callback::       proc(self: ^Bus(GBA_Processor_Mode), new_output: GBA_Processor_Mode) {  }
gba_TBIT_callback::    proc(self: ^Line, new_output: bool) { }
gba_A_callback::       proc(self: ^Bus(u32), new_output: u32) {  }
gba_DOUT_callback::    proc(self: ^Bus(u32), new_output: u32) {  }
gba_D_callback::       proc(self: ^Bus(u32), new_output: u32) {  }
gba_DIN_callback::     proc(self: ^Bus(u32), new_output: u32) {  }
gba_MREQ_callback::    proc(self: ^Line, new_output: bool) {

}
gba_sequential_cycle_callback::     proc(self: ^Line, new_output: bool) { }
gba_RW_callback::      proc(self: ^Line, new_output: bool) { }
gba_MAS_callback::     proc(self: ^Bus(uint), new_output: uint) {  }
gba_BL_callback::      proc(self: ^Bus(u8), new_output: u8) {  }
gba_LOCK_callback::    proc(self: ^Line, new_output: bool) { }


// DECODER & CONTROL //
gba_should_be_zero:: proc(bits: u32, #any_int num: uint) -> bool {
	mask: u32 = (u32(0b1) << num) - 1
	return (bits & mask) == 0b00000000_00000000_00000000_00000000 }
gba_should_be_one:: proc(bits: u32, #any_int num: uint) -> bool {
	mask: u32 = (u32(0b1) << num) - 1
	return (bits & mask) == 0b11111111_11111111_11111111_11111111 }


// CORE //
R13_DEFAULT_USER_SYSTEM:: 0x03007f00
R13_DEFAULT_IRQ::         0x03007fa0
R13_DEFAULT_SUPERVISOR::  0x03007fe0
GBA_Core:: struct {
	mode: GBA_Processor_Mode,
	logical_registers: GBA_Logical_Registers,
	physical_registers: GBA_Physical_Registers,
	using interface: GBA_Core_Interface }
gba_core: ^GBA_Core
CURRENT_STATE:: 0
PREVIOUS_STATE:: 1
gba_core_states: [2]^GBA_Core
init_gba_core:: proc() {
	gba_core_states[CURRENT_STATE], gba_core_states[PREVIOUS_STATE] = new(GBA_Core), new(GBA_Core)
	gba_core = gba_core_states[CURRENT_STATE]
	init_gba_core_interface() }
Hardware_Interrupt:: enum {
	V_BLANK,
	H_BLANK,
	SERIAL,
	V_COUNT,
	TIMER,
	DMA,
	KEY,
	CARTRIDGE }
Software_Interrupt:: enum {
	SOFT_RESET=              0x00,
	REGISTER_RAM_RESET=      0x01,
	HALT=                    0x02,
	STOP=                    0x03,
	INTR_WAIT=               0x04,
	V_BLANK_INTR_WAIT=       0x05,
	DIV=                     0x06,
	DIV_ARM=                 0x07,
	SQRT=                    0x08,
	ARC_TAN=                 0x09,
	ARC_TAN_2=               0x0A,
	CPU_SET=                 0x0B,
	CPU_FAST_SET=            0x0C,
	BIOS_CHECKSUM=           0x0D,
	BG_AFFINE_SET=           0x0E,
	OBJ_AFFINE_SET=          0x0F,
	BIT_UNPACK=              0x10,
	LZ77_UNCOMP_WRAM=        0x11,
	LZ77_UNCOMP_VRAM=        0x12,
	HUFF_UNCOMP=             0x13,
	RL_UNCOMP_WRAM=          0x14,
	RL_UNCOMP_VRAM=          0x15,
	DIFF_8BIT_UNFILTER_WRAM= 0x16,
	DIFF_8BIT_UNFILTER_VRAM= 0x17,
	DIFF_16BIT_UNFILTER=     0x18,
	SOUND_BIAS_CHANGE=       0x19,
	SOUND_DRIVER_INIT=       0x1A,
	SOUND_DRIVER_MODE=       0x1B,
	SOUND_DRIVER_MAIN=       0x1C,
	SOUND_DRIVER_VSYNC=      0x1D,
	SOUND_CHANNEL_CLEAR=     0x1E,
	MIDI_KEY_2FREQ=          0x1F,
	MUSIC_PLAYER_OPEN=       0x20,
	MUSIC_PLAYER_START=      0x21,
	MUSIC_PLAYER_STOP=       0x22,
	MUSIC_PLAYER_CONTINUE=   0x23,
	MUSIC_PLAYER_FADE_OUT=   0x24,
	MULTI_BOOT=              0x25,
	SOUND_DRIVER_VSYNC_OFF=  0x28,
	SOUND_DRIVER_VSYNC_ON=   0x29 }


// PROGRAM COUNTER //
// NOTE These depend on how I emulate and syncronize instruction pipelining. //
// gba_address_of_current_instruction:: proc() -> u32 {
// 	return gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^
// }
// gba_address_of_next_instruction:: proc() -> u32 {
// }


// INSTRUCTIONS //
gba_execute_ADC:: proc(ins: GBA_ADC_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	ins.destination^ = transmute(u32)(ins.operand + ins.shifter_operand + i32(cpsr.carry))
	if ins.set_condition_codes && ins.destination == gba_core.logical_registers.array[GBA_Logical_Register_Name.PC] {
		gba_pop_psr() }
	else if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destination^, 31, 1))
		cpsr.zero = (ins.destination^ == 0)
		cpsr.carry = gba_carry_from_add(ins.operand, ins.shifter_operand, u32(cpsr.carry))
		cpsr.overflow = gba_overflow_from_add(ins.operand, ins.shifter_operand, u32(cpsr.carry)) } }
gba_execute_ADD:: proc(ins: GBA_ADD_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	ins.destination^ = transmute(u32)(ins.operand + ins.shifter_operand)
	if ins.set_condition_codes && ins.destination == gba_core.logical_registers.array[GBA_Logical_Register_Name.PC] {
		gba_pop_psr() }
	else if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destination^, 31, 1))
		cpsr.zero = (ins.destination^ == 0)
		cpsr.carry = gba_carry_from_add(ins.operand, ins.shifter_operand)
		cpsr.overflow = gba_overflow_from_add(ins.operand, ins.shifter_operand) } }
gba_execute_AND:: proc(ins: GBA_AND_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	ins.destination^ = ins.operand & ins.shifter_operand
	if ins.set_condition_codes && ins.destination == gba_core.logical_registers.array[GBA_Logical_Register_Name.PC] {
		gba_pop_psr() }
	else if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destination^, 31, 1))
		cpsr.zero = (ins.destination^ == 0)
		cpsr.carry = ins.shifter_carry_out } }
gba_execute_B:: proc(ins: GBA_B_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^ = ins.target_address }
gba_execute_BL:: proc(ins: GBA_BL_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	gba_core.logical_registers.array[GBA_Logical_Register_Name.LR]^ = ins.instruction_address + 4
	gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^ = ins.target_address }
gba_execute_BIC:: proc(ins: GBA_BIC_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	ins.destination^ = ins.operand & (~ ins.shifter_operand)
	if ins.set_condition_codes && ins.destination == gba_core.logical_registers.array[GBA_Logical_Register_Name.PC] {
		gba_pop_psr() }
	else if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destination^, 31, 1))
		cpsr.zero = (ins.destination^ == 0)
		cpsr.carry = ins.shifter_carry_out } }
gba_execute_BX:: proc(ins: GBA_BX_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^ = ins.target_address
	cpsr.thumb_state = true }
gba_execute_CMN:: proc(ins: GBA_CMN_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	alu_out: i32 = ins.operand + ins.shifter_operand
	cpsr.negative = bool(bits.bitfield_extract(alu_out, 31, 1))
	cpsr.zero = (alu_out == 0)
	cpsr.carry = gba_carry_from_add(ins.operand, ins.shifter_operand)
	cpsr.overflow = gba_overflow_from_add(ins.operand, ins.shifter_operand) }
gba_execute_CMP:: proc(ins: GBA_CMP_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	alu_out: i32 = ins.operand - ins.shifter_operand
	cpsr.negative = bool(bits.bitfield_extract(alu_out, 31, 1))
	cpsr.zero = (alu_out == 0)
	cpsr.carry = gba_borrow_from(ins.operand, ins.shifter_operand)
	cpsr.overflow = gba_overflow_from_sub(ins.operand, ins.shifter_operand) }
gba_execute_EOR:: proc(ins: GBA_EOR_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	ins.destination^ = ins.operand ~ ins.shifter_operand
	if ins.set_condition_codes && ins.destination == gba_core.logical_registers.array[GBA_Logical_Register_Name.PC] {
		gba_pop_psr() }
	else if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destination^, 31, 1))
		cpsr.zero = (ins.destination^ == 0)
		cpsr.carry = ins.shifter_carry_out } }
gba_execute_LDM:: proc(ins: GBA_LDM_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	address: = ins.start_address
	for register in GBA_Logical_Register_Name(0) ..< GBA_Logical_Register_Name(15) {
		if register in ins.destination_registers {
			gba_core.logical_registers.array[register]^ = memory_read_u32(address)
			address += 4 } }
	if ins.restore_status_register do gba_pop_psr() }
gba_execute_LDR:: proc(ins: GBA_LDR_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	tail_bits: = bits.bitfield_extract(ins.address, 0, 2)
	switch tail_bits {
	case 0b00: ins.destination^ = memory_read_u32(ins.address)
	case 0b01: ins.destination^ = rotate_right(memory_read_u32(ins.address), 8)
	case 0b10: ins.destination^ = rotate_right(memory_read_u32(ins.address), 16)
	case 0b11: ins.destination^ = rotate_right(memory_read_u32(ins.address), 24) } }
gba_execute_LDRB:: proc(ins: GBA_LDRB_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	ins.destination^ = cast(u32)memory_read_u8(ins.address) }
gba_execute_LDRBT:: proc(ins: GBA_LDRBT_Instruction_Decoded) {
	// TODO Do the write-back on all instructions. //
	if ! gba_condition_passed(ins.cond) do return
	ins.destination^ = cast(u32)memory_read_u8(ins.address) }
gba_execute_LDRH:: proc(ins: GBA_LDRH_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	ins.destination^ = cast(u32)memory_read_u16(ins.address) }
gba_execute_LDRSB:: proc(ins: GBA_LDRSB_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	ins.destination^ = transmute(u32)gba_sign_extend(cast(u32)memory_read_u8(ins.address), 8) }
gba_execute_LDRSH:: proc(ins: GBA_LDRSH_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	ins.destination^ = transmute(u32)gba_sign_extend(cast(u32)memory_read_u16(ins.address), 16) }
gba_execute_LDRT:: proc(ins: GBA_LDRT_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	tail_bits: = bits.bitfield_extract(ins.address, 0, 2)
	switch tail_bits {
	case 0b00: ins.destination^ = memory_read_u32(ins.address)
	case 0b01: ins.destination^ = rotate_right(memory_read_u32(ins.address), 8)
	case 0b10: ins.destination^ = rotate_right(memory_read_u32(ins.address), 16)
	case 0b11: ins.destination^ = rotate_right(memory_read_u32(ins.address), 24) } }
gba_execute_MLA:: proc(ins: GBA_MLA_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	ins.destination^ = transmute(u32)(ins.operand * ins.multiplicand + ins.addend)
	if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destination^, 31, 1))
		cpsr.zero = (ins.destination^ == 0)
		cpsr.carry = bool(rand.int_max(2)) } }
gba_execute_MOV:: proc(ins: GBA_MOV_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	if ins.set_condition_codes && ins.destination == gba_core.logical_registers.array[GBA_Logical_Register_Name.PC] {
		gba_pop_psr() }
	ins.destination^ = ins.shifter_operand
	if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destination^, 31, 1))
		cpsr.zero = (ins.destination^ == 0)
		cpsr.carry = ins.shifter_carry_out } }
gba_execute_MRS:: proc(ins: GBA_MRS_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	ins.source^ = ins.destination^ }
gba_execute_MSR:: proc(ins: GBA_MSR_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr, spsr: = gba_get_cpsr(), gba_get_spsr()
	#partial switch ins.destination {
	case .CPSR:
		if 0 in ins.field_mask && gba_in_a_privileged_mode() {
			cpsr^ = auto_cast bits.bitfield_insert(cast(u32)cpsr^, bits.bitfield_extract(ins.operand, 0, 8), 0, 8) }
		if 1 in ins.field_mask && gba_in_a_privileged_mode() {
			cpsr^ = auto_cast bits.bitfield_insert(cast(u32)cpsr^, bits.bitfield_extract(ins.operand, 8, 8), 8, 8) }
		if 2 in ins.field_mask && gba_in_a_privileged_mode() {
			cpsr^ = auto_cast bits.bitfield_insert(cast(u32)cpsr^, bits.bitfield_extract(ins.operand, 16, 8), 16, 8) }
		if 3 in ins.field_mask {
			cpsr^ = auto_cast bits.bitfield_insert(cast(u32)cpsr^, bits.bitfield_extract(ins.operand, 24, 8), 24, 8) }
	case .SPSR:
		if 0 in ins.field_mask && gba_current_mode_has_spsr() {
			spsr^ = auto_cast bits.bitfield_insert(cast(u32)spsr^, bits.bitfield_extract(ins.operand, 0, 8), 0, 8) }
		if 1 in ins.field_mask && gba_current_mode_has_spsr() {
			spsr^ = auto_cast bits.bitfield_insert(cast(u32)spsr^, bits.bitfield_extract(ins.operand, 8, 8), 8, 8) }
		if 2 in ins.field_mask && gba_current_mode_has_spsr() {
			spsr^ = auto_cast bits.bitfield_insert(cast(u32)spsr^, bits.bitfield_extract(ins.operand, 16, 8), 16, 8) }
		if 3 in ins.field_mask && gba_current_mode_has_spsr() {
			spsr^ = auto_cast bits.bitfield_insert(cast(u32)spsr^, bits.bitfield_extract(ins.operand, 24, 8), 24, 8) } } }
gba_execute_MUL:: proc(ins: GBA_MUL_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	ins.destination^ = transmute(u32)(ins.operand * ins.multiplicand)
	if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destination^, 31, 1))
		cpsr.zero = (ins.destination^ == 0)
		cpsr.carry = bool(rand.int_max(2)) } }
gba_execute_MVN:: proc(ins: GBA_MVN_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	ins.destination^ = ~ ins.shifter_operand
	if ins.set_condition_codes && ins.destination == gba_core.logical_registers.array[GBA_Logical_Register_Name.PC] {
		gba_pop_psr() }
	if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destination^, 31, 1))
		cpsr.zero = (ins.destination^ == 0)
		cpsr.carry = ins.shifter_carry_out } }
gba_execute_ORR:: proc(ins: GBA_ORR_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	ins.destination^ = ins.operand | ins.shifter_operand
	if ins.set_condition_codes && ins.destination == gba_core.logical_registers.array[GBA_Logical_Register_Name.PC] {
		gba_pop_psr() }
	else if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destination^, 31, 1))
		cpsr.zero = (ins.destination^ == 0)
		cpsr.carry = ins.shifter_carry_out } }
gba_execute_RSB:: proc(ins: GBA_RSB_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	ins.destination^ = transmute(u32)(ins.shifter_operand - ins.operand)
	if ins.set_condition_codes && ins.destination == gba_core.logical_registers.array[GBA_Logical_Register_Name.PC] {
		gba_pop_psr() }
	else if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destination^, 31, 1))
		cpsr.zero = (ins.destination^ == 0)
		cpsr.carry = ! gba_borrow_from(ins.shifter_operand, ins.operand)
		cpsr.overflow = gba_overflow_from_sub(ins.shifter_operand, ins.operand) } }
gba_execute_RSC:: proc(ins: GBA_RSC_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	ins.destination^ = transmute(u32)(ins.shifter_operand - (ins.operand + i32(! cpsr.carry)))
	if ins.set_condition_codes && ins.destination == gba_core.logical_registers.array[GBA_Logical_Register_Name.PC] {
		gba_pop_psr() }
	else if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destination^, 31, 1))
		cpsr.zero = (ins.destination^ == 0)
		cpsr.carry = ! gba_borrow_from(ins.shifter_operand, (ins.operand + i32(! cpsr.carry)))
		cpsr.overflow = gba_overflow_from_sub(ins.shifter_operand, (ins.operand + i32(! cpsr.carry))) } }
gba_execute_SBC:: proc(ins: GBA_SBC_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	ins.destination^ = transmute(u32)(ins.operand - (ins.shifter_operand + i32(! cpsr.carry)))
	if ins.set_condition_codes && ins.destination == gba_core.logical_registers.array[GBA_Logical_Register_Name.PC] {
		gba_pop_psr() }
	else if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destination^, 31, 1))
		cpsr.zero = (ins.destination^ == 0)
		cpsr.carry = ! gba_borrow_from(ins.operand, (ins.shifter_operand + i32(! cpsr.carry)))
		cpsr.overflow = gba_overflow_from_sub(ins.operand, (ins.shifter_operand + i32(! cpsr.carry))) } }
gba_execute_SMLAL:: proc(ins: GBA_SMLAL_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	accumulator: i64 = transmute(i64)(u64(ins.destinations[0]^) | (u64(ins.destinations[1]^) << 32))
	product: i64 = i64(ins.multiplicands[0]) * i64(ins.multiplicands[1])
	accumulated_product: i64 = accumulator + product
	ins.destinations[0]^ = cast(u32)(transmute(u64)(accumulated_product & 0xFFFFFFFF))
	ins.destinations[1]^ = cast(u32)(transmute(u64)(accumulated_product >> 32))
	if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destinations[1]^, 31, 1))
		cpsr.zero = ((ins.destinations[0]^ == 0) && (ins.destinations[1]^ == 0))
		cpsr.carry = bool(rand.int_max(2))
		cpsr.overflow = bool(rand.int_max(2)) } }
gba_execute_SMULL:: proc(ins: GBA_SMULL_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	product: i64 = i64(ins.multiplicands[0]) * i64(ins.multiplicands[1])
	ins.destinations[0]^ = cast(u32)(transmute(u64)(product & 0xFFFFFFFF))
	ins.destinations[1]^ = cast(u32)(transmute(u64)(product >> 32))
	if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destinations[1]^, 31, 1))
		cpsr.zero = ((ins.destinations[0]^ == 0) && (ins.destinations[1]^ == 0))
		cpsr.carry = bool(rand.int_max(2))
		cpsr.overflow = bool(rand.int_max(2)) } }
gba_execute_STM:: proc(ins: GBA_STM_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	address: = ins.start_address
	for register in GBA_Logical_Register_Name(0) ..< GBA_Logical_Register_Name(15) {
		if register in ins.source_registers {
			memory_write_u32(address, gba_core.logical_registers.array[register]^)
			address += 4 } }
	if ins.restore_status_register do gba_pop_psr() }
gba_execute_STR:: proc(ins: GBA_STR_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	memory_write_u32(ins.address, ins.source^) }
gba_execute_STRB:: proc(ins: GBA_STRB_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	memory_write_u8(ins.address, cast(u8)(ins.source^ & 0xFF)) }
gba_execute_STRBT:: proc(ins: GBA_STRBT_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	memory_write_u8(ins.address, cast(u8)(ins.source^ & 0xFF)) }
gba_execute_STRH:: proc(ins: GBA_STRH_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	memory_write_u16(ins.address, cast(u16)(ins.source^ & 0xFFFF)) }
gba_execute_STRT:: proc(ins: GBA_STRT_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	memory_write_u32(ins.address, ins.source^) }
gba_execute_SUB:: proc(ins: GBA_SUB_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	ins.destination^ = transmute(u32)(ins.operand - ins.shifter_operand)
	if ins.set_condition_codes && ins.destination == gba_core.logical_registers.array[GBA_Logical_Register_Name.PC] {
		gba_pop_psr() }
	else if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destination^, 31, 1))
		cpsr.zero = (ins.destination^ == 0)
		cpsr.carry = ! gba_borrow_from(ins.operand, ins.shifter_operand)
		cpsr.overflow = gba_overflow_from_sub(ins.operand, ins.shifter_operand) } }
gba_execute_SWI:: proc(ins: GBA_SWI_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	gba_core.physical_registers.array[GBA_Physical_Register_Name.R14_SVC] = ins.instruction_address + 4
	gba_core.physical_registers.array[GBA_Physical_Register_Name.SPSR_SVC] = cast(u32)cpsr^
	cpsr^ = auto_cast bits.bitfield_insert(cast(u32)cpsr^, 0b010011, 0, 6)
	cpsr^ = auto_cast bits.bitfield_insert(cast(u32)cpsr^, 0b1, 7, 1)
	gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^ = 0x08 }
gba_execute_SWP:: proc(ins: GBA_SWP_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	temp: u32 = memory_read_u32(ins.address)
	memory_write_u32(ins.address, ins.source_register^)
	ins.destination_register^ = temp }
gba_execute_SWPB:: proc(ins: GBA_SWPB_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	temp: u8 = memory_read_u8(ins.address)
	memory_write_u8(ins.address, cast(u8)(ins.source_register^ & 0xFF))
	ins.destination_register^ = u32(temp) }
gba_execute_TEQ:: proc(ins: GBA_TEQ_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	alu_out: u32 = ins.operand ~ ins.shifter_operand
	cpsr.negative = bool(bits.bitfield_extract(alu_out, 31, 1))
	cpsr.zero = (alu_out == 0)
	cpsr.carry = ins.shifter_carry_out }
gba_execute_TST:: proc(ins: GBA_TST_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	alu_out: u32 = ins.operand & ins.shifter_operand
	cpsr.negative = bool(bits.bitfield_extract(alu_out, 31, 1))
	cpsr.zero = (alu_out == 0)
	cpsr.carry = ins.shifter_carry_out }
gba_execute_UMLAL:: proc(ins: GBA_UMLAL_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	accumulator: u64 = u64(ins.destinations[0]^) | (u64(ins.destinations[1]^) << 32)
	product: u64 = u64(ins.multiplicands[0]) * u64(ins.multiplicands[1])
	accumulated_product: u64 = accumulator + product
	ins.destinations[0]^ = cast(u32)(accumulated_product & 0xFFFFFFFF)
	ins.destinations[1]^ = cast(u32)(accumulated_product >> 32)
	if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destinations[1]^, 31, 1))
		cpsr.zero = ((ins.destinations[0]^ == 0) && (ins.destinations[1]^ == 0))
		cpsr.carry = bool(rand.int_max(2))
		cpsr.overflow = bool(rand.int_max(2)) } }
gba_execute_UMULL:: proc(ins: GBA_UMULL_Instruction_Decoded) {
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	product: u64 = u64(ins.multiplicands[0]) * u64(ins.multiplicands[1])
	ins.destinations[0]^ = cast(u32)(product & 0xFFFFFFFF)
	ins.destinations[1]^ = cast(u32)(product >> 32)
	if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destinations[1]^, 31, 1))
		cpsr.zero = ((ins.destinations[0]^ == 0) && (ins.destinations[1]^ == 0))
		cpsr.carry = bool(rand.int_max(2))
		cpsr.overflow = bool(rand.int_max(2)) } }


