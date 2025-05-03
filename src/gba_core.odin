#+feature dynamic-literals
package gbana
import "core:fmt"
import "core:container/queue"
import "core:math/bits"
import "core:math/rand"
import "core:encoding/endian"
import "core:thread"
import "core:log"


ALU:: struct { }


// INTERFACE //
GBA_Core_Interface:: struct {
	main_clock:                     Signal(bool),               // MCLK
	wait:                           Signal(bool),               // WAIT
	interrupt_request:              Signal(bool),               // IRQ
	fast_interrupt_request:         Signal(bool),               // FIQ
	synchronous_interrupts_enable:  Signal(bool),               // ISYNC
	reset:                          Signal(bool),               // RESET
	big_endian:                     Signal(bool),               // BIGEND
	input_enable:                   Signal(bool),               // ENIN
	output_enable:                  Signal(bool),               // ENOUT
	address_bus_enable:             Signal(bool),               // ABE
	address_latch_enable:           Signal(bool),               // ALE
	data_bus_enable:                Signal(bool),               // DBE
	processor_mode:                 Signal(GBA_Processor_Mode), // M
	executing_thumb:                Signal(bool),               // TBIT
	data_in:                        Signal(u32),                // DIN
	execute_cycle:                  Signal(bool),               // EXEC
	abort:                          Signal(bool) }              // ABORT
initialize_gba_core_interface:: proc() {
	using state: ^State = cast(^State)context.user_ptr
	gba_core.interface = {}
	signal_init("EXEC",   &gba_core.execute_cycle,                 1, gba_execute_cycle_callback,                 write_phase = { LOW_PHASE             })
	signal_init("MCLK",   &gba_core.main_clock,                    2, main_clock_callback,                        write_phase = { LOW_PHASE, HIGH_PHASE })
	signal_init("WAIT",   &gba_core.wait,                          1, gba_wait_callback,                          write_phase = { LOW_PHASE             })
	signal_init("IRQ",    &gba_core.interrupt_request,             1, gba_interrupt_request_callback,             write_phase = { HIGH_PHASE            })
	signal_init("FIQ",    &gba_core.fast_interrupt_request,        1, gba_fast_interrupt_request_callback,        write_phase = { HIGH_PHASE            })
	signal_init("ISYNC",  &gba_core.synchronous_interrupts_enable, 1, gba_synchronous_interrupts_enable_callback, write_phase = { LOW_PHASE, HIGH_PHASE })
	signal_init("RESET",  &gba_core.reset,                         1, gba_reset_callback,                         write_phase = { LOW_PHASE             })
	signal_init("BIGEND", &gba_core.big_endian,                    1, gba_big_endian_callback,                    write_phase = { HIGH_PHASE            })
	signal_init("ENIN",   &gba_core.input_enable,                  1, gba_input_enable_callback,                  write_phase = { LOW_PHASE, HIGH_PHASE })
	signal_init("ENOUT",  &gba_core.output_enable,                 1, gba_output_enable_callback,                 write_phase = { LOW_PHASE, HIGH_PHASE })
	signal_init("DBE",    &gba_core.data_bus_enable,               1, gba_data_bus_enable_callback,               write_phase = { LOW_PHASE             })
	signal_init("M",      &gba_core.processor_mode,                1, gba_processor_mode_callback,                write_phase = { HIGH_PHASE            })
	signal_init("TBIT",   &gba_core.executing_thumb,               1, gba_executing_thumb_callback,               write_phase = { HIGH_PHASE            })
	signal_init("DIN",    &gba_core.data_in,                       1, gba_data_in_callback,                       write_phase = { HIGH_PHASE            })
	signal_init("ABE",    &gba_core.address_bus_enable,            1, gba_address_bus_enable_callback,            write_phase = { LOW_PHASE             })
	signal_init("ALE",    &gba_core.address_latch_enable,          1, gba_address_latch_enable_callback,          write_phase = { LOW_PHASE, HIGH_PHASE })
	signal_init("ABORT",  &gba_core.abort,                         1, gba_abort_callback,                         write_phase = { LOW_PHASE, HIGH_PHASE })
	signal_put(&gba_core.main_clock, true) }


// THREAD //
gba_core_thread_proc:: proc(t: ^thread.Thread) { }


// SIGNALS //
// gba_watch_signals:: proc() {
// 	using state: ^State = cast(^State)context.user_ptr
// 	if gba_core_states[CURRENT_STATE].reset.output != gba_core_states[PREVIOUS_STATE].reset.output do gba_signal_callback_reset() }
// gba_signal_callback_reset:: proc() {
// 	using state: ^State = cast(^State)context.user_ptr
// 	switch gba_core_states[CURRENT_STATE].reset.output {
// 	case HIGH:
// 		for i in uint(GBA_Physical_Register_Name.R0) ..< uint(GBA_Physical_Register_Name.CPSR) do gba_core.physical_registers.array[i] = rand.uint32()
// 		// TODO More information is provided in Reset sequence after power up on page 3-33. //
// 	case LOW:
// 		gba_core.physical_registers.array[GBA_Physical_Register_Name.R14_SVC] = gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^
// 		gba_core.physical_registers.array[GBA_Physical_Register_Name.SPSR_SVC] = gba_core.logical_registers.array[GBA_Logical_Register_Name.CPSR]^
// 		signal_put(&gba_core.processor_mode, GBA_Processor_Mode.Supervisor)
// 		cpsr: = gba_get_cpsr()
// 		cpsr.irq_interrupt_disable = true
// 		cpsr.fiq_interrupt_disable = true
// 		cpsr.thumb_state = false
// 		gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^ = 0b0 } }
// NOTE Ignore the bounary-scan circuit stuff and the TAP controller. Those are for hardware circuit testing. //


// TODO 3-1 Memory Interface


// SIGNAL LOGIC //
gba_insert_wait_cycle:: proc() {
	using state: ^State = cast(^State)context.user_ptr
	signal_delay(&gba_core.main_clock, 2) }
gba_wait_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) { }
gba_interrupt_request_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) { }
gba_fast_interrupt_request_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) { }
gba_synchronous_interrupts_enable_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) { }
gba_reset_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) {
	using state: ^State = cast(^State)context.user_ptr
	if new_output == false {
		signal_put(&memory.memory_request, true, latency_override = 4)
		signal_put(&gba_core.execute_cycle, true, latency_override = 5)
		signal_put(&memory.sequential_cycle, true, latency_override = 6) } }
gba_big_endian_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) { }
gba_input_enable_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) { }
gba_output_enable_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) { }
gba_address_bus_enable_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) { }
gba_address_latch_enable_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) { }
gba_data_bus_enable_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) { }
gba_processor_mode_callback:: proc(self: ^Signal(GBA_Processor_Mode), old_output, new_output: GBA_Processor_Mode) {  }
gba_executing_thumb_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) { }
gba_data_in_callback:: proc(self: ^Signal(u32), old_output, new_output: u32) {  }
gba_execute_cycle_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) { }
gba_abort_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) { }


// SEQUENCES //
GBA_Sequence_Type:: enum { MEMORY, INTERNAL }
gba_request_memory_sequence:: proc(sequential_cycle: bool = false, read_write: Memory_Read_Write = .READ, address: u32 = 0b0, data_out: u32 = 0b0, memory_access_size: Memory_Access_Size = .WORD, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	if phase_index != 0 do log.fatal("Sequence may only be requested in phase 1.", location = loc)
	if sequential_cycle {
		// log.info(memory.address.output, "-------->", address)
		if address < memory.address.output do log.fatal("S-Cycle may not be requested on an address lower than the address of the previous access.", location = loc)
		else if address == memory.address.output { }
		else if memory_access_size == .BYTE do log.fatal("S-Cycle not allowed for byte-size memory access.", location = loc)
		else if (memory_access_size == .HALFWORD) && (address != memory.address.output + 2) do log.fatal("Halfword-size memory access requires halfword address increment.", location = loc)
		else if (memory_access_size == .WORD) && (address != memory.address.output + 4) do log.fatal("Word-size memory access requires word address increment.", location = loc) }
	signal_force(&memory.memory_request, HIGH)
	signal_force(&memory.sequential_cycle, sequential_cycle)
	signal_force(&memory.read_write, read_write)
	signal_force(&memory.memory_access_size, memory_access_size)
	signal_put(&memory.read_write, read_write, latency_override = 1)
	signal_put(&memory.address, address, latency_override = 2)
	if read_write == .WRITE do signal_put(&memory.data_out, data_out, latency_override = 2) }
gba_request_n_cycle:: proc(read_write: Memory_Read_Write = .READ, address: u32 = 0b0, data_out: u32 = 0b0, memory_access_size: Memory_Access_Size = .WORD, loc: = #caller_location) {
	gba_request_memory_sequence(sequential_cycle = false, read_write = read_write, address = address, data_out = data_out, memory_access_size = memory_access_size) }
gba_request_s_cycle:: proc(read_write: Memory_Read_Write = .READ, address: u32 = 0b0, data_out: u32 = 0b0, memory_access_size: Memory_Access_Size = .WORD, loc: = #caller_location) {
	gba_request_memory_sequence(sequential_cycle = true, read_write = read_write, address = address, data_out = data_out, memory_access_size = memory_access_size) }
gba_initiate_i_cycle:: proc(loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	if phase_index != 0 do log.fatal("Sequence may only be requested in phase 1.", location = loc)
	signal_force(&memory.memory_request, LOW)
	signal_force(&memory.sequential_cycle, LOW) }
gba_request_merged_is_cycle:: proc(read_write: Memory_Read_Write = .READ, address: u32 = 0b0, data_out: u32 = 0b0, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	if phase_index != 0 do log.fatal("Sequence may only be requested in phase 1.", location = loc)
	signal_force(&memory.memory_request, LOW)
	signal_force(&memory.sequential_cycle, LOW)
	signal_put(&memory.memory_request, HIGH, latency_override = 2)
	signal_put(&memory.sequential_cycle, HIGH, latency_override = 2)
	signal_put(&memory.read_write, read_write, latency_override = 2)
	signal_put(&memory.address, address, latency_override = 2)
	if read_write == .WRITE do signal_put(&memory.data_out, data_out, latency_override = 2) }
gba_request_data_write_cycle:: proc(sequential_cycle: bool = false, address: u32 = 0b0, data_out: u32 = 0b0, memory_access_size: Memory_Access_Size = .WORD, loc: = #caller_location) {
	gba_request_memory_sequence(sequential_cycle, .WRITE, address, data_out, memory_access_size, loc) }
gba_request_data_read_cycle:: proc(sequential_cycle: bool = false, address: u32 = 0b0, memory_access_size: Memory_Access_Size = .WORD, loc: = #caller_location) {
	gba_request_memory_sequence(sequential_cycle, .READ, address, 0b0, memory_access_size, loc) }
gba_request_halfword_memory_sequence:: proc(sequential_cycle: bool = false, read_write: Memory_Read_Write = .READ, address: u32 = 0b0, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	if phase_index != 0 do log.fatal("Sequence may only be requested in phase 1.", location = loc) }
gba_request_byte_memory_sequence:: proc(sequential_cycle: bool = false, read_write: Memory_Read_Write = .READ, address: u32 = 0b0, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	if phase_index != 0 do log.fatal("Sequence may only be requested in phase 1.", location = loc) }
gba_initiate_reset_sequence:: proc(loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	if phase_index != 0 do log.fatal("Sequence may only be requested in phase 1.", location = loc) }
gba_request_branch_and_branch_with_link_instruction_cycle:: proc(instruction: GBA_Branch_and_Link_Instruction_Decoded, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	if phase_index != 0 do log.fatal("Sequence may only be requested in phase 1.", location = loc) }
gba_request_thumb_branch_with_link_instruction_cycle:: proc(loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	if phase_index != 0 do log.fatal("Sequence may only be requested in phase 1.", location = loc) }
gba_request_branch_and_exchange_instruction_cycle:: proc(instruction: GBA_Branch_and_Exchange_Instruction_Decoded, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	if phase_index != 0 do log.fatal("Sequence may only be requested in phase 1.", location = loc) }
gba_request_data_processing_instruction_cycle:: proc(alu: u32, destination_is_pc: bool, shift_specified_by_register: bool, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	if phase_index != 0 do log.fatal("Sequence may only be requested in phase 1.", location = loc)
	pc: = gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^
	L: u32 = gba_core.executing_thumb.output ? 2 : 4
	i: Memory_Access_Size = gba_core.executing_thumb.output ? .HALFWORD : .WORD
	switch {
	// normal //
	case (! shift_specified_by_register) && (! destination_is_pc):
		signal_force(&memory.memory_request, HIGH)
		signal_force(&memory.sequential_cycle, HIGH)
		signal_force(&memory.op_code_fetch, HIGH)
		signal_force(&memory.read_write, Memory_Read_Write.READ)
		signal_force(&memory.address, pc + 2 * L)
		signal_force(&memory.memory_access_size, i)
	// dest=pc //
	case (! shift_specified_by_register) && destination_is_pc:
	// shift(RS) //
	case shift_specified_by_register && (! destination_is_pc):
	// shift(RS) dest=pc //
	case shift_specified_by_register && destination_is_pc:
	case:
	}
}
gba_request_multiply_and_multiply_accumulate_instruction_cycle:: proc(instruction: GBA_Multiply_and_Multiply_Accumulate_Instruction_Decoded, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	if phase_index != 0 do log.fatal("Multiply and Multiply Accumulate Instruction Cycle may only be requested in phase 1", location = loc) }
gba_request_load_register_instruction_cycle:: proc(instruction: GBA_Load_Register_Instruction_Decoded, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	if phase_index != 0 do log.fatal("Load Register Instruction Cycle may only be requested in phase 1", location = loc) }
gba_request_store_register_instruction_cycle:: proc(instruction: GBA_Store_Register_Instruction_Decoded, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	if phase_index != 0 do log.fatal("Store Register Instruction Cycle may only be requested in phase 1", location = loc) }
gba_request_load_multiple_register_instruction_cycle:: proc(instruction: GBA_Load_Multiple_Register_Instruction_Decoded, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	if phase_index != 0 do log.fatal("Load Multiple Register Instruction Cycle may only be requested in phase 1", location = loc) }
gba_request_store_multiple_register_instruction_cycle:: proc(instruction: GBA_Store_Multiple_Register_Instruction_Decoded, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	if phase_index != 0 do log.fatal("Store Multiple Register Instruction Cycle may only be requested in phase 1", location = loc) }
gba_request_data_swap_instruction_cycle:: proc(instruction: GBA_Data_Swap_Instruction_Decoded, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	if phase_index != 0 do log.fatal("Data Swap Instruction Cycle may only be requested in phase 1", location = loc) }
gba_request_software_interrupt_and_exception_instruction_cycle:: proc(instruction: GBA_Software_Interrupt_Instruction_Decoded, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	if phase_index != 0 do log.fatal("Software Interrupt and Exception Instruction Cycle may only be requested in phase 1", location = loc) }
gba_request_undefined_instruction_cycle:: proc(loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	if phase_index != 0 do log.fatal("Undefined Instruction Cycle may only be requested in phase 1", location = loc) }
gba_request_unexecuted_instruction_cycle:: proc(loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	if phase_index != 0 do log.fatal("Unexecuted Instruction Cycle may only be requested in phase 1", location = loc) }


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
initialize_gba_core:: proc() {
	using state: ^State = cast(^State)context.user_ptr
	gba_set_mode_initial()
	initialize_gba_core_interface() }
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
	using state: ^State = cast(^State)context.user_ptr
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
	using state: ^State = cast(^State)context.user_ptr
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
	using state: ^State = cast(^State)context.user_ptr
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
	using state: ^State = cast(^State)context.user_ptr
	if ! gba_condition_passed(ins.cond) do return
	gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^ = ins.target_address }
gba_execute_BL:: proc(ins: GBA_BL_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	if ! gba_condition_passed(ins.cond) do return
	gba_core.logical_registers.array[GBA_Logical_Register_Name.LR]^ = ins.instruction_address + 4
	gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^ = ins.target_address }
gba_execute_BIC:: proc(ins: GBA_BIC_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
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
	using state: ^State = cast(^State)context.user_ptr
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^ = ins.target_address
	cpsr.thumb_state = true }
gba_execute_CMN:: proc(ins: GBA_CMN_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	alu_out: i32 = ins.operand + ins.shifter_operand
	cpsr.negative = bool(bits.bitfield_extract(alu_out, 31, 1))
	cpsr.zero = (alu_out == 0)
	cpsr.carry = gba_carry_from_add(ins.operand, ins.shifter_operand)
	cpsr.overflow = gba_overflow_from_add(ins.operand, ins.shifter_operand) }
gba_execute_CMP:: proc(ins: GBA_CMP_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	alu_out: i32 = ins.operand - ins.shifter_operand
	cpsr.negative = bool(bits.bitfield_extract(alu_out, 31, 1))
	cpsr.zero = (alu_out == 0)
	cpsr.carry = gba_borrow_from(ins.operand, ins.shifter_operand)
	cpsr.overflow = gba_overflow_from_sub(ins.operand, ins.shifter_operand) }
gba_execute_EOR:: proc(ins: GBA_EOR_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
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
	using state: ^State = cast(^State)context.user_ptr
	if ! gba_condition_passed(ins.cond) do return
	address: = ins.start_address
	for register in GBA_Logical_Register_Name(0) ..< GBA_Logical_Register_Name(15) {
		if register in ins.destination_registers {
			gba_core.logical_registers.array[register]^ = memory_read_u32(address)
			address += 4 } }
	if ins.restore_status_register do gba_pop_psr() }
gba_execute_LDR:: proc(ins: GBA_LDR_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	if ! gba_condition_passed(ins.cond) do return
	tail_bits: = bits.bitfield_extract(ins.address, 0, 2)
	switch tail_bits {
	case 0b00: ins.destination^ = memory_read_u32(ins.address)
	case 0b01: ins.destination^ = rotate_right(memory_read_u32(ins.address), 8)
	case 0b10: ins.destination^ = rotate_right(memory_read_u32(ins.address), 16)
	case 0b11: ins.destination^ = rotate_right(memory_read_u32(ins.address), 24) } }
gba_execute_LDRB:: proc(ins: GBA_LDRB_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	if ! gba_condition_passed(ins.cond) do return
	ins.destination^ = cast(u32)memory_read_u8(ins.address) }
gba_execute_LDRBT:: proc(ins: GBA_LDRBT_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	// TODO Do the write-back on all instructions. //
	if ! gba_condition_passed(ins.cond) do return
	ins.destination^ = cast(u32)memory_read_u8(ins.address) }
gba_execute_LDRH:: proc(ins: GBA_LDRH_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	if ! gba_condition_passed(ins.cond) do return
	ins.destination^ = cast(u32)memory_read_u16(ins.address) }
gba_execute_LDRSB:: proc(ins: GBA_LDRSB_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	if ! gba_condition_passed(ins.cond) do return
	ins.destination^ = transmute(u32)gba_sign_extend(cast(u32)memory_read_u8(ins.address), 8) }
gba_execute_LDRSH:: proc(ins: GBA_LDRSH_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	if ! gba_condition_passed(ins.cond) do return
	ins.destination^ = transmute(u32)gba_sign_extend(cast(u32)memory_read_u16(ins.address), 16) }
gba_execute_LDRT:: proc(ins: GBA_LDRT_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	if ! gba_condition_passed(ins.cond) do return
	tail_bits: = bits.bitfield_extract(ins.address, 0, 2)
	switch tail_bits {
	case 0b00: ins.destination^ = memory_read_u32(ins.address)
	case 0b01: ins.destination^ = rotate_right(memory_read_u32(ins.address), 8)
	case 0b10: ins.destination^ = rotate_right(memory_read_u32(ins.address), 16)
	case 0b11: ins.destination^ = rotate_right(memory_read_u32(ins.address), 24) } }
gba_execute_MLA:: proc(ins: GBA_MLA_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	ins.destination^ = transmute(u32)(ins.operand * ins.multiplicand + ins.addend)
	if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destination^, 31, 1))
		cpsr.zero = (ins.destination^ == 0)
		cpsr.carry = bool(rand.int_max(2)) } }
gba_execute_MOV:: proc(ins: GBA_MOV_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
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
	using state: ^State = cast(^State)context.user_ptr
	if ! gba_condition_passed(ins.cond) do return
	ins.source^ = ins.destination^ }
gba_execute_MSR:: proc(ins: GBA_MSR_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
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
	using state: ^State = cast(^State)context.user_ptr
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	ins.destination^ = transmute(u32)(ins.operand * ins.multiplicand)
	if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destination^, 31, 1))
		cpsr.zero = (ins.destination^ == 0)
		cpsr.carry = bool(rand.int_max(2)) } }
gba_execute_MVN:: proc(ins: GBA_MVN_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
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
	using state: ^State = cast(^State)context.user_ptr
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
	using state: ^State = cast(^State)context.user_ptr
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
	using state: ^State = cast(^State)context.user_ptr
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
	using state: ^State = cast(^State)context.user_ptr
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
	using state: ^State = cast(^State)context.user_ptr
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
	using state: ^State = cast(^State)context.user_ptr
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
	using state: ^State = cast(^State)context.user_ptr
	if ! gba_condition_passed(ins.cond) do return
	address: = ins.start_address
	for register in GBA_Logical_Register_Name(0) ..< GBA_Logical_Register_Name(15) {
		if register in ins.source_registers {
			memory_write_u32(address, gba_core.logical_registers.array[register]^)
			address += 4 } }
	if ins.restore_status_register do gba_pop_psr() }
gba_execute_STR:: proc(ins: GBA_STR_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	if ! gba_condition_passed(ins.cond) do return
	memory_write_u32(ins.address, ins.source^) }
gba_execute_STRB:: proc(ins: GBA_STRB_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	if ! gba_condition_passed(ins.cond) do return
	memory_write_u8(ins.address, cast(u8)(ins.source^ & 0xFF)) }
gba_execute_STRBT:: proc(ins: GBA_STRBT_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	if ! gba_condition_passed(ins.cond) do return
	memory_write_u8(ins.address, cast(u8)(ins.source^ & 0xFF)) }
gba_execute_STRH:: proc(ins: GBA_STRH_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	if ! gba_condition_passed(ins.cond) do return
	memory_write_u16(ins.address, cast(u16)(ins.source^ & 0xFFFF)) }
gba_execute_STRT:: proc(ins: GBA_STRT_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	if ! gba_condition_passed(ins.cond) do return
	memory_write_u32(ins.address, ins.source^) }
gba_execute_SUB:: proc(ins: GBA_SUB_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
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
	using state: ^State = cast(^State)context.user_ptr
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	gba_core.physical_registers.array[GBA_Physical_Register_Name.R14_SVC] = ins.instruction_address + 4
	gba_core.physical_registers.array[GBA_Physical_Register_Name.SPSR_SVC] = cast(u32)cpsr^
	cpsr^ = auto_cast bits.bitfield_insert(cast(u32)cpsr^, 0b010011, 0, 6)
	cpsr^ = auto_cast bits.bitfield_insert(cast(u32)cpsr^, 0b1, 7, 1)
	gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^ = 0x08 }
gba_execute_SWP:: proc(ins: GBA_SWP_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	if ! gba_condition_passed(ins.cond) do return
	temp: u32 = memory_read_u32(ins.address)
	memory_write_u32(ins.address, ins.source_register^)
	ins.destination_register^ = temp }
gba_execute_SWPB:: proc(ins: GBA_SWPB_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	if ! gba_condition_passed(ins.cond) do return
	temp: u8 = memory_read_u8(ins.address)
	memory_write_u8(ins.address, cast(u8)(ins.source_register^ & 0xFF))
	ins.destination_register^ = u32(temp) }
gba_execute_TEQ:: proc(ins: GBA_TEQ_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	alu_out: u32 = ins.operand ~ ins.shifter_operand
	cpsr.negative = bool(bits.bitfield_extract(alu_out, 31, 1))
	cpsr.zero = (alu_out == 0)
	cpsr.carry = ins.shifter_carry_out }
gba_execute_TST:: proc(ins: GBA_TST_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	alu_out: u32 = ins.operand & ins.shifter_operand
	cpsr.negative = bool(bits.bitfield_extract(alu_out, 31, 1))
	cpsr.zero = (alu_out == 0)
	cpsr.carry = ins.shifter_carry_out }
gba_execute_UMLAL:: proc(ins: GBA_UMLAL_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
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
	using state: ^State = cast(^State)context.user_ptr
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