#+feature dynamic-literals
package gbana
import "core:fmt"
import "core:container/queue"
import "core:math/bits"
import "core:math/rand"
import "core:encoding/endian"
import "core:thread"
import "core:log"
import "core:sync"


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
@(private="file") initialize_gba_core_interface:: proc() {
	using state: ^State = cast(^State)context.user_ptr
	gba_core.interface = {}
	signal_init("EXEC",   &gba_core.execute_cycle,                 1, gba_execute_cycle_callback,                 write_phase = { LOW_PHASE             })
	signal_init("MCLK",   &gba_core.main_clock,                    2, main_clock_callback,                        write_phase = { LOW_PHASE, HIGH_PHASE })
	signal_init("WAIT",   &gba_core.wait,                          1, gba_wait_callback,                          write_phase = { LOW_PHASE             })
	signal_init("IRQ",    &gba_core.interrupt_request,             1, gba_interrupt_request_callback,             write_phase = { HIGH_PHASE            })
	signal_init("FIQ",    &gba_core.fast_interrupt_request,        1, gba_fast_interrupt_request_callback,        write_phase = { HIGH_PHASE            })
	signal_init("ISYNC",  &gba_core.synchronous_interrupts_enable, 1, gba_synchronous_interrupts_enable_callback, write_phase = { LOW_PHASE, HIGH_PHASE })
	signal_init("RESET",  &gba_core.reset,                         1, gba_reset_callback,                         write_phase = { LOW_PHASE             })
	signal_init("BIGEND", &gba_core.big_endian,                    1, gba_big_endian_callback,                    write_phase = { LOW_PHASE             })
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
@(private="file") gba_insert_wait_cycle:: proc() {
	using state: ^State = cast(^State)context.user_ptr
	signal_delay(&gba_core.main_clock, 2) }
@(private="file") gba_wait_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) { }
@(private="file") gba_interrupt_request_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) { }
@(private="file") gba_fast_interrupt_request_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) { }
@(private="file") gba_synchronous_interrupts_enable_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) { }
@(private="file") gba_reset_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) { }
@(private="file") gba_big_endian_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) { }
@(private="file") gba_input_enable_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) { }
@(private="file") gba_output_enable_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) { }
@(private="file") gba_address_bus_enable_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) { }
@(private="file") gba_address_latch_enable_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) { }
@(private="file") gba_data_bus_enable_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) { }
@(private="file") gba_processor_mode_callback:: proc(self: ^Signal(GBA_Processor_Mode), old_output, new_output: GBA_Processor_Mode) {  }
@(private="file") gba_executing_thumb_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) { }
@(private="file") gba_data_in_callback:: proc(self: ^Signal(u32), old_output, new_output: u32) {  }
@(private="file") gba_execute_cycle_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) { }
@(private="file") gba_abort_callback:: proc(self: ^Signal(bool), old_output, new_output: bool) { }


// SEQUENCES //
GBA_Sequence_Type:: enum { MEMORY, INTERNAL }
gba_request_memory_sequence:: proc(sequential_cycle: bool = false, read_write: Memory_Read_Write = .READ, address: u32 = 0b0, data_out: u32 = 0b0, memory_access_size: Memory_Access_Size = .WORD, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	sync.recursive_mutex_lock(&gba_core.mutex); defer sync.recursive_mutex_unlock(&gba_core.mutex)
	if phase_index != 0 do log.fatal("Sequence may only be requested in phase 1.", location = loc)
	if sequential_cycle {
		// log.info(memory.address.output, "-------->", address)
		if address < memory.address.output do log.fatal("S-Cycle may not be requested on an address lower than the address of the previous access.", location = loc)
		else if address == memory.address.output { }
		else if memory_access_size == .BYTE do log.fatal("S-Cycle not allowed for byte-size memory access.", location = loc)
		else if (memory_access_size == .HALFWORD) && (address != memory.address.output + 2) do log.fatal("Halfword-size memory access requires halfword address increment.", location = loc)
		else if (memory_access_size == .WORD) && (address != memory.address.output + 4) do log.fatal("Word-size memory access requires word address increment.", location = loc) }
	signal_put(&memory.memory_request, HIGH, 0)
	signal_put(&memory.sequential_cycle, sequential_cycle, 0)
	signal_put(&memory.read_write, read_write, 0)
	signal_put(&memory.memory_access_size, memory_access_size, 0)
	signal_put(&memory.read_write, read_write, 1)
	signal_put(&memory.address, address, 2)
	if read_write == .WRITE do signal_put(&memory.data_out, data_out, 2) }
gba_request_N_cycle:: proc(read_write: Memory_Read_Write = .READ, address: u32 = 0b0, data_out: u32 = 0b0, memory_access_size: Memory_Access_Size = .WORD, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	sync.recursive_mutex_lock(&gba_core.mutex); defer sync.recursive_mutex_unlock(&gba_core.mutex)
	gba_request_memory_sequence(sequential_cycle = false, read_write = read_write, address = address, data_out = data_out, memory_access_size = memory_access_size) }
gba_request_S_cycle:: proc(read_write: Memory_Read_Write = .READ, address: u32 = 0b0, data_out: u32 = 0b0, memory_access_size: Memory_Access_Size = .WORD, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	sync.recursive_mutex_lock(&gba_core.mutex); defer sync.recursive_mutex_unlock(&gba_core.mutex)
	gba_request_memory_sequence(sequential_cycle = true, read_write = read_write, address = address, data_out = data_out, memory_access_size = memory_access_size) }
gba_initiate_I_cycle:: proc(loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	sync.recursive_mutex_lock(&gba_core.mutex); defer sync.recursive_mutex_unlock(&gba_core.mutex)
	if phase_index != 0 do log.fatal("Sequence may only be requested in phase 1.", location = loc)
	signal_put(&memory.memory_request, LOW, 0)
	signal_put(&memory.sequential_cycle, LOW, 0) }
gba_request_MIS_cycle:: proc(read_write: Memory_Read_Write = .READ, address: u32 = 0b0, data_out: u32 = 0b0, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	sync.recursive_mutex_lock(&gba_core.mutex); defer sync.recursive_mutex_unlock(&gba_core.mutex)
	if phase_index != 0 do log.fatal("Sequence may only be requested in phase 1.", location = loc)
	signal_put(&memory.memory_request, LOW, 0)
	signal_put(&memory.sequential_cycle, LOW, 0)
	signal_put(&memory.memory_request, HIGH, 2)
	signal_put(&memory.sequential_cycle, HIGH, 2)
	signal_put(&memory.read_write, read_write, 2)
	signal_put(&memory.address, address, 2)
	if read_write == .WRITE do signal_put(&memory.data_out, data_out, 2) }
gba_request_DW_cycle:: proc(sequential_cycle: bool = false, address: u32 = 0b0, data_out: u32 = 0b0, memory_access_size: Memory_Access_Size = .WORD, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	sync.recursive_mutex_lock(&gba_core.mutex); defer sync.recursive_mutex_unlock(&gba_core.mutex)
	gba_request_memory_sequence(sequential_cycle, .WRITE, address, data_out, memory_access_size, loc) }
gba_request_DR_cycle:: proc(sequential_cycle: bool = false, address: u32 = 0b0, memory_access_size: Memory_Access_Size = .WORD, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	sync.recursive_mutex_lock(&gba_core.mutex); defer sync.recursive_mutex_unlock(&gba_core.mutex)
	gba_request_memory_sequence(sequential_cycle, .READ, address, 0b0, memory_access_size, loc) }
gba_request_RS_cycle:: proc(loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	sync.recursive_mutex_lock(&gba_core.mutex); defer sync.recursive_mutex_unlock(&gba_core.mutex)
	if phase_index != 0 do log.fatal("Sequence may only be requested in phase 1.", location = loc)
	signal_put(&gba_core.reset, HIGH, 0)
	signal_put(&gba_core.reset, LOW, 2)
	initial_address: u32 = cast(u32)rand.int31_max(0x00003fff/4)
	signal_put(&memory.address, initial_address, 2)
	signal_put(&memory.address, initial_address + 4, 4)
	signal_put(&memory.address, initial_address + 8, 6)
	signal_put(&memory.address, 0, 8)
	signal_put(&memory.memory_request, LOW, 0)
	signal_put(&memory.memory_request, HIGH, 6)
	signal_put(&memory.sequential_cycle, LOW, 0)
	signal_put(&memory.sequential_cycle, HIGH, 8)
	signal_put(&gba_core.execute_cycle, LOW, 0)
	signal_put(&gba_core.execute_cycle, HIGH, 6) }
gba_request_BABLI_cycle:: proc(alu: u32, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	sync.recursive_mutex_lock(&gba_core.mutex); defer sync.recursive_mutex_unlock(&gba_core.mutex)
	if phase_index != 0 do log.fatal("Sequence may only be requested in phase 1.", location = loc)
	pc: = gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^
	L: u32 = gba_core.executing_thumb.output ? 2 : 4
	i: Memory_Access_Size = gba_core.executing_thumb.output ? .HALFWORD : .WORD
	signal_put(&memory.memory_request, HIGH, 0)
	signal_put(&memory.sequential_cycle, LOW, 0)
	signal_put(&memory.sequential_cycle, HIGH, 2)
	signal_put(&memory.op_code_fetch, HIGH, 0)
	signal_put(&memory.read_write, Memory_Read_Write.READ, 0)
	signal_put(&memory.address, pc + 2 * L, 0)
	signal_put(&memory.address, alu, 2)
	signal_put(&memory.address, alu + L, 4)
	signal_put(&memory.address, alu + 2 * L, 6)
	signal_put(&memory.memory_access_size, i, 0) }
gba_request_TBLI_cycle:: proc(alu: u32, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	sync.recursive_mutex_lock(&gba_core.mutex); defer sync.recursive_mutex_unlock(&gba_core.mutex)
	if phase_index != 0 do log.fatal("Sequence may only be requested in phase 1.", location = loc)
	pc: = gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^
	signal_put(&memory.memory_request, HIGH, 0)
	signal_put(&memory.sequential_cycle, HIGH, 0)
	signal_put(&memory.sequential_cycle, LOW, 2)
	signal_put(&memory.sequential_cycle, HIGH, 4)
	signal_put(&memory.op_code_fetch, HIGH, 0)
	signal_put(&memory.read_write, Memory_Read_Write.READ, 0)
	signal_put(&memory.address, pc + 4, 0)
	signal_put(&memory.address, pc + 6, 2)
	signal_put(&memory.address, alu, 4)
	signal_put(&memory.address, alu + 2, 6)
	signal_put(&memory.address, alu + 4, 8)
	signal_put(&memory.memory_access_size, Memory_Access_Size.HALFWORD, 0) }
gba_request_BAEI_cycle:: proc(alu: u32, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	sync.recursive_mutex_lock(&gba_core.mutex); defer sync.recursive_mutex_unlock(&gba_core.mutex)
	if phase_index != 0 do log.fatal("Sequence may only be requested in phase 1.", location = loc)
	pc: = gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^
	T: = gba_core.executing_thumb.output
	t: = ! T
	W: u32 = T ? 2 : 4
	w: u32 = T ? 4 : 2
	I: Memory_Access_Size = T ? .HALFWORD : .WORD
	i: Memory_Access_Size = T ? .WORD : .HALFWORD
	signal_put(&memory.memory_request, HIGH, 0)
	signal_put(&memory.sequential_cycle, LOW, 0)
	signal_put(&memory.sequential_cycle, HIGH, 2)
	signal_put(&memory.op_code_fetch, HIGH, 0)
	signal_put(&memory.read_write, Memory_Read_Write.READ, 0)
	signal_put(&gba_core.executing_thumb, t, 3)
	signal_put(&memory.address, pc + 2 * W, 0)
	signal_put(&memory.address, alu, 2)
	signal_put(&memory.address, alu + w, 2)
	signal_put(&memory.address, alu + 2 * w, 2)
	signal_put(&memory.memory_access_size, I, 0)
	signal_put(&memory.memory_access_size, i, 2) }
gba_request_DPI_cycle:: proc(alu: u32, destination_is_pc: bool, shift_specified_by_register: bool, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	sync.recursive_mutex_lock(&gba_core.mutex); defer sync.recursive_mutex_unlock(&gba_core.mutex)
	if phase_index != 0 do log.fatal("Sequence may only be requested in phase 1.", location = loc)
	pc: = gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^
	L: u32 = gba_core.executing_thumb.output ? 2 : 4
	i: Memory_Access_Size = gba_core.executing_thumb.output ? .HALFWORD : .WORD
	switch {
	case (! shift_specified_by_register) && (! destination_is_pc): // normal //
		signal_put(&memory.memory_request, HIGH, 0)
		signal_put(&memory.sequential_cycle, HIGH, 0)
		signal_put(&memory.op_code_fetch, HIGH, 0)
		signal_put(&memory.read_write, Memory_Read_Write.READ, 0)
		signal_put(&memory.address, pc + 2 * L, 0)
		signal_put(&memory.memory_access_size, i, 0)
	case (! shift_specified_by_register) && destination_is_pc: // dest=pc //
		signal_put(&memory.memory_request, HIGH, 0)
		signal_put(&memory.sequential_cycle, LOW, 0)
		signal_put(&memory.sequential_cycle, HIGH, 2)
		signal_put(&memory.op_code_fetch, HIGH, 0)
		signal_put(&memory.read_write, Memory_Read_Write.READ, 0)
		signal_put(&memory.address, pc + 2 * L, 0)
		signal_put(&memory.address, alu, 2)
		signal_put(&memory.address, alu + L, 4)
		signal_put(&memory.address, alu + 2 * L, 6)
		signal_put(&memory.memory_access_size, i, 0)
	case shift_specified_by_register && (! destination_is_pc): // shift(RS) //
		signal_put(&memory.memory_request, LOW, 0)
		signal_put(&memory.memory_request, HIGH, 2)
		signal_put(&memory.sequential_cycle, LOW, 0)
		signal_put(&memory.sequential_cycle, HIGH, 2)
		signal_put(&memory.op_code_fetch, HIGH, 0)
		signal_put(&memory.op_code_fetch, LOW, 2)
		signal_put(&memory.read_write, Memory_Read_Write.READ, 0)
		signal_put(&memory.address, pc + 2 * L, 0)
		signal_put(&memory.address, pc + 3 * L, 2)
		signal_put(&memory.memory_access_size, i, 0)
	case shift_specified_by_register && destination_is_pc: // shift(RS) dest=pc //
		signal_put(&memory.memory_request, LOW, 0)
		signal_put(&memory.memory_request, HIGH, 2)
		signal_put(&memory.sequential_cycle, LOW, 0)
		signal_put(&memory.sequential_cycle, HIGH, 4)
		signal_put(&memory.op_code_fetch, HIGH, 0)
		signal_put(&memory.op_code_fetch, LOW, 2)
		signal_put(&memory.op_code_fetch, HIGH, 4)
		signal_put(&memory.read_write, Memory_Read_Write.READ, 0)
		signal_put(&memory.address, pc + 8, 0)
		signal_put(&memory.address, pc + 12, 2)
		signal_put(&memory.address, alu, 4)
		signal_put(&memory.address, alu + 4, 6)
		signal_put(&memory.address, alu + 8, 8)
		signal_put(&memory.memory_access_size, Memory_Access_Size.WORD, 0)
	case: } }
gba_request_MAMAI_cycle:: proc(accumulate: bool, long: bool, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	sync.recursive_mutex_lock(&gba_core.mutex); defer sync.recursive_mutex_unlock(&gba_core.mutex)
	if phase_index != 0 do log.fatal("Sequence may only be requested in phase 1.", location = loc)
	pc: = gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^
	L: u32 = gba_core.executing_thumb.output ? 2 : 4
	i: Memory_Access_Size = gba_core.executing_thumb.output ? .HALFWORD : .WORD
	switch {
	case (! accumulate) && (! long):
		signal_put(&memory.memory_request, LOW, 0)
		signal_put(&memory.memory_request, HIGH, 4)
		signal_put(&memory.sequential_cycle, LOW, 0)
		signal_put(&memory.sequential_cycle, HIGH, 4)
		signal_put(&memory.op_code_fetch, HIGH, 0)
		signal_put(&memory.op_code_fetch, LOW, 2)
		signal_put(&memory.read_write, Memory_Read_Write.READ, 0)
		signal_put(&memory.address, pc + 2 * L, 0)
		signal_put(&memory.address, pc + 3 * L, 2)
		signal_put(&memory.memory_access_size, i, 0)
	case accumulate && (! long):
		signal_put(&memory.memory_request, LOW, 0)
		signal_put(&memory.memory_request, HIGH, 6)
		signal_put(&memory.sequential_cycle, LOW, 0)
		signal_put(&memory.sequential_cycle, HIGH, 6)
		signal_put(&memory.op_code_fetch, HIGH, 0)
		signal_put(&memory.op_code_fetch, LOW, 2)
		signal_put(&memory.read_write, Memory_Read_Write.READ, 0)
		signal_put(&memory.address, pc + 8, 0)
		signal_put(&memory.address, pc + 12, 4)
		signal_put(&memory.memory_access_size, Memory_Access_Size.WORD, 0)
	case (! accumulate) && long:
		signal_put(&memory.memory_request, LOW, 0)
		signal_put(&memory.memory_request, HIGH, 4)
		signal_put(&memory.sequential_cycle, LOW, 0)
		signal_put(&memory.sequential_cycle, HIGH, 4)
		signal_put(&memory.op_code_fetch, HIGH, 0)
		signal_put(&memory.op_code_fetch, LOW, 2)
		signal_put(&memory.read_write, Memory_Read_Write.READ, 0)
		signal_put(&memory.address, pc + 8, 0)
		signal_put(&memory.address, pc + 12, 2)
		signal_put(&memory.memory_access_size, i, 0)
	case accumulate && long:
		signal_put(&memory.memory_request, LOW, 0)
		signal_put(&memory.memory_request, HIGH, 6)
		signal_put(&memory.sequential_cycle, LOW, 0)
		signal_put(&memory.sequential_cycle, HIGH, 6)
		signal_put(&memory.op_code_fetch, HIGH, 0)
		signal_put(&memory.op_code_fetch, LOW, 2)
		signal_put(&memory.read_write, Memory_Read_Write.READ, 0)
		signal_put(&memory.address, pc + 8, 0)
		signal_put(&memory.address, pc + 12, 4)
		signal_put(&memory.memory_access_size, Memory_Access_Size.WORD, 0) } }
gba_request_LRI_cycle:: proc(alu: u32, destination_is_pc: bool, pc_prim: u32, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	sync.recursive_mutex_lock(&gba_core.mutex); defer sync.recursive_mutex_unlock(&gba_core.mutex)
	if phase_index != 0 do log.fatal("Sequence may only be requested in phase 1.", location = loc)
	pc: = gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^
	L: u32 = gba_core.executing_thumb.output ? 2 : 4
	i: Memory_Access_Size = gba_core.executing_thumb.output ? .HALFWORD : .WORD
	s: = i
	switch {
	case (! destination_is_pc):
		signal_put(&memory.memory_request, HIGH, 0)
		signal_put(&memory.memory_request, LOW, 2)
		signal_put(&memory.memory_request, HIGH, 4)
		signal_put(&memory.sequential_cycle, LOW, 0)
		signal_put(&memory.sequential_cycle, HIGH, 4)
		signal_put(&memory.op_code_fetch, HIGH, 0)
		signal_put(&memory.op_code_fetch, LOW, 2)
		signal_put(&memory.read_write, Memory_Read_Write.READ, 0)
		signal_put(&memory.address, pc + 2 * L, 0)
		signal_put(&memory.address, alu, 2)
		signal_put(&memory.address, pc + 3 * L, 4)
		signal_put(&memory.memory_access_size, i, 0)
		signal_put(&memory.memory_access_size, s, 2)
		signal_put(&memory.memory_access_size, i, 4)
	case destination_is_pc:
		signal_put(&memory.memory_request, HIGH, 0)
		signal_put(&memory.memory_request, LOW, 2)
		signal_put(&memory.memory_request, HIGH, 4)
		signal_put(&memory.sequential_cycle, LOW, 0)
		signal_put(&memory.sequential_cycle, HIGH, 6)
		signal_put(&memory.op_code_fetch, HIGH, 0)
		signal_put(&memory.op_code_fetch, LOW, 2)
		signal_put(&memory.op_code_fetch, HIGH, 6)
		signal_put(&memory.read_write, Memory_Read_Write.READ, 0)
		signal_put(&memory.address, pc + 8, 0)
		signal_put(&memory.address, alu, 2)
		signal_put(&memory.address, pc + 12, 4)
		signal_put(&memory.address, pc_prim, 6)
		signal_put(&memory.address, pc_prim + 4, 8)
		signal_put(&memory.address, pc_prim + 8, 10)
		signal_put(&memory.memory_access_size, Memory_Access_Size.WORD, 0) } }
gba_request_SRI_cycle:: proc(alu: u32, Rd: u32, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	sync.recursive_mutex_lock(&gba_core.mutex); defer sync.recursive_mutex_unlock(&gba_core.mutex)
	if phase_index != 0 do log.fatal("Sequence may only be requested in phase 1.", location = loc)
	pc: = gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^
	L: u32 = gba_core.executing_thumb.output ? 2 : 4
	i: Memory_Access_Size = gba_core.executing_thumb.output ? .HALFWORD : .WORD
	s: = i
	signal_put(&memory.memory_request, HIGH, 0)
	signal_put(&memory.sequential_cycle, LOW, 0)
	signal_put(&memory.op_code_fetch, HIGH, 0)
	signal_put(&memory.op_code_fetch, LOW, 2)
	signal_put(&memory.read_write, Memory_Read_Write.READ, 0)
	signal_put(&memory.read_write, Memory_Read_Write.WRITE, 1)
	signal_put(&memory.read_write, Memory_Read_Write.READ, 2)
	signal_put(&memory.read_write, Memory_Read_Write.WRITE, 3)
	signal_put(&memory.read_write, Memory_Read_Write.READ, 4)
	signal_put(&memory.read_write, Memory_Read_Write.WRITE, 5)
	// log.info(memory.read_write)
	// log.info("QUEUE LEN =", queue.len(memory.read_write._queue))
	signal_put(&memory.address, pc + 2 * L, 0)
	signal_put(&memory.memory_access_size, i, 0)
	signal_put(&memory.memory_access_size, s, 2)
	signal_put(&memory.data_out, Rd, 2) }
gba_request_LMRI_cycle:: proc(alu: u32, include_pc: bool, n: int, pc_prim: u32, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	sync.recursive_mutex_lock(&gba_core.mutex); defer sync.recursive_mutex_unlock(&gba_core.mutex)
	if phase_index != 0 do log.fatal("Sequence may only be requested in phase 1.", location = loc)
	pc: = gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^
	L: u32 = gba_core.executing_thumb.output ? 2 : 4
	i: Memory_Access_Size = gba_core.executing_thumb.output ? .HALFWORD : .WORD
	switch {
	case (n == 1) && (! include_pc): // single register //
		signal_put(&memory.memory_request, HIGH, 0)
		signal_put(&memory.memory_request, LOW, 2)
		signal_put(&memory.sequential_cycle, HIGH, 0)
		signal_put(&memory.sequential_cycle, LOW, 4)
		signal_put(&memory.op_code_fetch, HIGH, 0)
		signal_put(&memory.op_code_fetch, LOW, 2)
		signal_put(&memory.read_write, Memory_Read_Write.READ, 0)
		signal_put(&memory.address, pc + 2 * L, 0)
		signal_put(&memory.address, alu, 2)
		signal_put(&memory.address, pc + 3 * L, 4)
		signal_put(&memory.memory_access_size, i, 0)
		signal_put(&memory.memory_access_size, Memory_Access_Size.WORD, 2)
		signal_put(&memory.memory_access_size, i, 4)
	case (n == 1) && include_pc: // single register dest=pc //
		signal_put(&memory.memory_request, HIGH, 0)
		signal_put(&memory.memory_request, LOW, 2)
		signal_put(&memory.memory_request, HIGH, 4)
		signal_put(&memory.sequential_cycle, LOW, 0)
		signal_put(&memory.sequential_cycle, HIGH, 6)
		signal_put(&memory.op_code_fetch, HIGH, 0)
		signal_put(&memory.op_code_fetch, LOW, 2)
		signal_put(&memory.op_code_fetch, HIGH, 6)
		signal_put(&memory.read_write, Memory_Read_Write.READ, 0)
		signal_put(&memory.address, pc + 2 * L, 0)
		signal_put(&memory.address, alu, 2)
		signal_put(&memory.address, pc + 3 * L, 4)
		signal_put(&memory.address, pc_prim, 6)
		signal_put(&memory.address, pc_prim + L, 8)
		signal_put(&memory.address, pc_prim + 2 * L, 10)
		signal_put(&memory.memory_access_size, i, 0)
		signal_put(&memory.memory_access_size, Memory_Access_Size.WORD, 2)
		signal_put(&memory.memory_access_size, i, 4)
	case (n > 1) && (! include_pc): // n registers //
		signal_put(&memory.memory_request, HIGH, 0)
		signal_put(&memory.memory_request, LOW, 2 * n)
		signal_put(&memory.memory_request, HIGH, 2 * n + 2)
		signal_put(&memory.sequential_cycle, LOW, 0)
		signal_put(&memory.sequential_cycle, HIGH, 2)
		signal_put(&memory.sequential_cycle, LOW, 2 * n)
		signal_put(&memory.sequential_cycle, HIGH, 2 * n + 2)
		signal_put(&memory.op_code_fetch, HIGH, 0)
		signal_put(&memory.op_code_fetch, LOW, 2)
		signal_put(&memory.read_write, Memory_Read_Write.READ, 0)
		signal_put(&memory.address, pc + 2 * L, 0)
		for k in u32(0) ..< u32(n - 1) do signal_put(&memory.address, alu + 4 * k, int(2 + 2 * k))
		signal_put(&memory.memory_access_size, i, 0)
		signal_put(&memory.memory_access_size, Memory_Access_Size.WORD, 2)
		signal_put(&memory.memory_access_size, i, 2 * n + 2)
	case (n > 1) && include_pc: // n registers including pc //
		signal_put(&memory.memory_request, HIGH, 0)
		signal_put(&memory.memory_request, LOW, 2 * n)
		signal_put(&memory.memory_request, HIGH, 2 * n + 2)
		signal_put(&memory.sequential_cycle, LOW, 0)
		signal_put(&memory.sequential_cycle, HIGH, 2)
		signal_put(&memory.sequential_cycle, LOW, 2 * n)
		signal_put(&memory.sequential_cycle, HIGH, 2 * n + 4)
		signal_put(&memory.op_code_fetch, HIGH, 0)
		signal_put(&memory.op_code_fetch, LOW, 2)
		signal_put(&memory.op_code_fetch, HIGH, 2 * n + 4)
		signal_put(&memory.read_write, Memory_Read_Write.READ, 0)
		signal_put(&memory.address, pc + 2 * L, 0)
		for k in u32(0) ..< u32(n) do signal_put(&memory.address, alu + 4 * k, int(2 + 2 * k))
		signal_put(&memory.address, pc + 3 * L, 2 * n + 2)
		signal_put(&memory.address, pc_prim + L, 2 * n + 4)
		signal_put(&memory.address, pc_prim + 2 * L, 2 * n + 6)
		signal_put(&memory.memory_access_size, i, 0)
		signal_put(&memory.memory_access_size, Memory_Access_Size.WORD, 2)
		signal_put(&memory.memory_access_size, i, 2 * n + 2) } }
gba_request_SMRI_cycle:: proc(alu: u32, n: int, R: []u32, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	sync.recursive_mutex_lock(&gba_core.mutex); defer sync.recursive_mutex_unlock(&gba_core.mutex)
	if phase_index != 0 do log.fatal("Sequence may only be requested in phase 1.", location = loc)
	pc: = gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^
	L: u32 = gba_core.executing_thumb.output ? 2 : 4
	i: Memory_Access_Size = gba_core.executing_thumb.output ? .HALFWORD : .WORD
	switch {
	case n == 1: // single register //
		signal_put(&memory.memory_request, HIGH, 0)
		signal_put(&memory.sequential_cycle, LOW, 0)
		signal_put(&memory.op_code_fetch, HIGH, 0)
		signal_put(&memory.op_code_fetch, LOW, 2)
		signal_put(&memory.read_write, Memory_Read_Write.READ, 0)
		signal_put(&memory.read_write, Memory_Read_Write.WRITE, 2)
		signal_put(&memory.address, pc + 2 * L, 0)
		signal_put(&memory.address, alu, 2)
		signal_put(&memory.address, pc + 3 * L, 4)
		signal_put(&memory.memory_access_size, i, 0)
		signal_put(&memory.memory_access_size, Memory_Access_Size.WORD, 2)
		signal_put(&memory.data_out, R[0], 2)
	case n > 1: // n registers //
		signal_put(&memory.memory_request, HIGH, 0)
		signal_put(&memory.sequential_cycle, LOW, 0)
		signal_put(&memory.sequential_cycle, HIGH, 2)
		signal_put(&memory.sequential_cycle, LOW, 2 + 2 * (n - 1))
		signal_put(&memory.op_code_fetch, HIGH, 0)
		signal_put(&memory.op_code_fetch, LOW, 2)
		signal_put(&memory.read_write, Memory_Read_Write.READ, 0)
		signal_put(&memory.read_write, Memory_Read_Write.WRITE, 2)
		signal_put(&memory.address, pc + 8, 0)
		for k in u32(0) ..< u32(n) do signal_put(&memory.address, alu + 4 * k, int(2 + k * 2))
		signal_put(&memory.address, pc + 12, 6 + n * 2)
		signal_put(&memory.memory_access_size, i, 0)
		signal_put(&memory.memory_access_size, Memory_Access_Size.WORD, 2)
		signal_put(&memory.memory_access_size, i, 4 + n * 2)
		for k in u32(0) ..< u32(n) do signal_put(&memory.data_out, R[k], int(2 + 2 * k)) } }
gba_request_DSI_cycle:: proc(Rn: u32, Rm: u32, s: Memory_Access_Size, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	sync.recursive_mutex_lock(&gba_core.mutex); defer sync.recursive_mutex_unlock(&gba_core.mutex)
	if phase_index != 0 do log.fatal("Sequence may only be requested in phase 1.", location = loc)
	pc: = gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^
	signal_put(&memory.memory_request, HIGH, 0)
	signal_put(&memory.memory_request, LOW, 4)
	signal_put(&memory.memory_request, HIGH, 6)
	signal_put(&memory.sequential_cycle, LOW, 0)
	signal_put(&memory.sequential_cycle, HIGH, 6)
	signal_put(&memory.op_code_fetch, HIGH, 0)
	signal_put(&memory.op_code_fetch, LOW, 2)
	signal_put(&memory.read_write, Memory_Read_Write.READ, 0)
	signal_put(&memory.read_write, Memory_Read_Write.WRITE, 4)
	signal_put(&memory.read_write, Memory_Read_Write.READ, 6)
	signal_put(&memory.address, pc + 8, 0)
	signal_put(&memory.address, Rn, 2)
	signal_put(&memory.address, pc + 12, 6)
	signal_put(&memory.memory_access_size, Memory_Access_Size.WORD, 0)
	signal_put(&memory.memory_access_size, s, 2)
	signal_put(&memory.memory_access_size, Memory_Access_Size.WORD, 6)
	signal_put(&memory.data_out, Rm, 4) }
gba_request_SIAEI_cycle:: proc(Xn: u32, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	sync.recursive_mutex_lock(&gba_core.mutex); defer sync.recursive_mutex_unlock(&gba_core.mutex)
	if phase_index != 0 do log.fatal("Sequence may only be requested in phase 1.", location = loc)
	pc: = gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^
	L: u32 = gba_core.executing_thumb.output ? 2 : 4
	i: Memory_Access_Size = gba_core.executing_thumb.output ? .HALFWORD : .WORD
	signal_put(&memory.memory_request, HIGH, 0)
	signal_put(&memory.sequential_cycle, LOW, 0)
	signal_put(&memory.sequential_cycle, HIGH, 2)
	signal_put(&memory.op_code_fetch, HIGH, 0)
	signal_put(&memory.op_code_fetch, LOW, 2)
	signal_put(&gba_core.executing_thumb, LOW, 2)
	signal_put(&memory.read_write, Memory_Read_Write.READ, 0)
	signal_put(&memory.address, pc + 2 * L, 0)
	signal_put(&memory.address, Xn, 2)
	signal_put(&memory.address, Xn + 4, 4)
	signal_put(&memory.address, Xn + 8, 6)
	signal_put(&memory.memory_access_size, i, 0)
	signal_put(&memory.memory_access_size, Memory_Access_Size.WORD, 2) }
gba_request_UDI_cycle:: proc(Xn: u32, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	sync.recursive_mutex_lock(&gba_core.mutex); defer sync.recursive_mutex_unlock(&gba_core.mutex)
	if phase_index != 0 do log.fatal("Sequence may only be requested in phase 1.", location = loc)
	pc: = gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^
	L: u32 = gba_core.executing_thumb.output ? 2 : 4
	i: Memory_Access_Size = gba_core.executing_thumb.output ? .HALFWORD : .WORD
	signal_put(&memory.memory_request, LOW, 0)
	signal_put(&memory.memory_request, HIGH, 2)
	signal_put(&memory.sequential_cycle, LOW, 0)
	signal_put(&memory.sequential_cycle, HIGH, 4)
	signal_put(&memory.op_code_fetch, HIGH, 0)
	signal_put(&gba_core.executing_thumb, LOW, 4)
	signal_put(&memory.read_write, Memory_Read_Write.READ, 0)
	signal_put(&memory.address, pc + 2 * L, 0)
	signal_put(&memory.address, Xn, 4)
	signal_put(&memory.address, Xn + 4, 6)
	signal_put(&memory.address, Xn + 8, 8)
	signal_put(&memory.memory_access_size, i, 0)
	signal_put(&memory.memory_access_size, Memory_Access_Size.WORD, 4) }
gba_request_UEI_cycle:: proc(loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	sync.recursive_mutex_lock(&gba_core.mutex); defer sync.recursive_mutex_unlock(&gba_core.mutex)
	if phase_index != 0 do log.fatal("Sequence may only be requested in phase 1.", location = loc)
	pc: = gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^
	L: u32 = gba_core.executing_thumb.output ? 2 : 4
	i: Memory_Access_Size = gba_core.executing_thumb.output ? .HALFWORD : .WORD
	signal_put(&memory.memory_request, HIGH, 0)
	signal_put(&memory.sequential_cycle, LOW, 0)
	signal_put(&memory.op_code_fetch, HIGH, 0)
	signal_put(&memory.read_write, Memory_Read_Write.READ, 0)
	signal_put(&memory.address, pc + 2 * L, 0)
	signal_put(&memory.address, pc + 3 * L, 2)
	signal_put(&memory.memory_access_size, i, 0) }


// DECODER & CONTROL //
@(private="file") gba_should_be_zero:: proc(bits: u32, #any_int num: uint) -> bool {
	mask: u32 = (u32(0b1) << num) - 1
	return (bits & mask) == 0b00000000_00000000_00000000_00000000 }
@(private="file") gba_should_be_one:: proc(bits: u32, #any_int num: uint) -> bool {
	mask: u32 = (u32(0b1) << num) - 1
	return (bits & mask) == 0b11111111_11111111_11111111_11111111 }


// CORE //
R13_DEFAULT_USER_SYSTEM:: 0x03007f00
R13_DEFAULT_IRQ::         0x03007fa0
R13_DEFAULT_SUPERVISOR::  0x03007fe0
GBA_Core:: struct {
	mutex:              sync.Recursive_Mutex,
	mode:               GBA_Processor_Mode,
	logical_registers:  GBA_Logical_Registers,
	physical_registers: GBA_Physical_Registers,
	using interface:    GBA_Core_Interface }
initialize_gba_core:: proc() {
	using state: ^State = cast(^State)context.user_ptr
	sync.recursive_mutex_lock(&gba_core.mutex); defer sync.recursive_mutex_unlock(&gba_core.mutex)
	gba_set_mode_initial()
	initialize_gba_core_interface() }
gba_register_name:: proc(register_address: rawptr) -> string {
	using state: ^State = cast(^State)context.user_ptr
	switch register_address {
	case &gba_core.physical_registers.r0:         return "R0"
	case &gba_core.physical_registers.r1:         return "R1"
	case &gba_core.physical_registers.r2:         return "R2"
	case &gba_core.physical_registers.r3:         return "R3"
	case &gba_core.physical_registers.r4:         return "R4"
	case &gba_core.physical_registers.r5:         return "R5"
	case &gba_core.physical_registers.r6:         return "R6"
	case &gba_core.physical_registers.r7:         return "R7"
	case &gba_core.physical_registers.r8:         return "R8"
	case &gba_core.physical_registers.r9:         return "R9"
	case &gba_core.physical_registers.r10:        return "R10"
	case &gba_core.physical_registers.r11:        return "R11"
	case &gba_core.physical_registers.r12:        return "R12"
	case &gba_core.physical_registers.r13:        return "R13"
	case &gba_core.physical_registers.r14:        return "R14"
	case &gba_core.physical_registers.r13_svc:    return "R13_SVC"
	case &gba_core.physical_registers.r14_svc:    return "R14_SVC"
	case &gba_core.physical_registers.r13_abort:  return "R13_ABORT"
	case &gba_core.physical_registers.r14_abort:  return "R14_ABORT"
	case &gba_core.physical_registers.r13_undef:  return "R13_UNDEF"
	case &gba_core.physical_registers.r14_undef:  return "R14_UNDEF"
	case &gba_core.physical_registers.r13_irq:    return "R13_IRQ"
	case &gba_core.physical_registers.r14_irq:    return "R14_IRQ"
	case &gba_core.physical_registers.r8_fiq:     return "R8_FIQ"
	case &gba_core.physical_registers.r9_fiq:     return "R9_FIQ"
	case &gba_core.physical_registers.r10_fiq:    return "R10_FIQ"
	case &gba_core.physical_registers.r11_fiq:    return "R11_FIQ"
	case &gba_core.physical_registers.r12_fiq:    return "R12_FIQ"
	case &gba_core.physical_registers.r13_fiq:    return "R13_FIQ"
	case &gba_core.physical_registers.r14_fiq:    return "R14_FIQ"
	case &gba_core.physical_registers.cpsr:       return "CPSR"
	case &gba_core.physical_registers.spsr_svc:   return "SPSR_SVC"
	case &gba_core.physical_registers.spsr_abort: return "SPSR_ABORT"
	case &gba_core.physical_registers.spsr_undef: return "SPSR_UNDEF"
	case &gba_core.physical_registers.spsr_irq:   return "SPSR_IRQ"
	case &gba_core.physical_registers.spsr_fiq:   return "SPSR_FIQ"
	case &gba_core.physical_registers.pc:         return "PC"
	case:                                         log.panic("invalid register address") } }
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
@(private="file") gba_address_of_current_instruction:: proc() -> u32 {
	using state: ^State = cast(^State)context.user_ptr
	return gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^ }
// gba_address_of_next_instruction:: proc() -> u32 { return 0 }
@(private="file") gba_increment_pc:: proc() {
	using state: ^State = cast(^State)context.user_ptr
	gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^ += 4 }
@(private="file") gba_get_pc:: proc() -> u32 {
	using state: ^State = cast(^State)context.user_ptr
	return gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^ }
@(private="file") gba_set_pc:: proc(value: u32) {
	using state: ^State = cast(^State)context.user_ptr
	gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^ = value }


// INSTRUCTIONS //
gba_execute_next:: proc() {
	using state: ^State = cast(^State)context.user_ptr
	sync.recursive_mutex_lock(&gba_core.mutex); defer sync.recursive_mutex_unlock(&gba_core.mutex)
	pc: ^u32 = gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]
	ins_address: = pc^
	ins: GBA_Instruction = le_to_be(cast(GBA_Instruction)memory_read_u32(ins_address))
	ins_identified, _: = gba_identify_instruction(ins)
	ins_decoded: GBA_Instruction_Decoded
	defined: bool
	ins_decoded, defined = gba_decode_identified(ins_identified, pc^)
	fmt.println(aprint_instruction_info(ins_address, ins, ins_decoded))
	gba_execute(ins_decoded) }
@(private="file") gba_execute:: proc(ins_decoded: GBA_Instruction_Decoded) {
	switch ins in ins_decoded {
	case GBA_ADC_Instruction_Decoded:   gba_execute_ADC(ins)
	case GBA_ADD_Instruction_Decoded:   gba_execute_ADD(ins)
	case GBA_AND_Instruction_Decoded:   gba_execute_AND(ins)
	case GBA_B_Instruction_Decoded:     gba_execute_B(ins)
	case GBA_BL_Instruction_Decoded:    gba_execute_BL(ins)
	case GBA_BIC_Instruction_Decoded:   gba_execute_BIC(ins)
	case GBA_BX_Instruction_Decoded:    gba_execute_BX(ins)
	case GBA_CMN_Instruction_Decoded:   gba_execute_CMN(ins)
	case GBA_CMP_Instruction_Decoded:   gba_execute_CMP(ins)
	case GBA_EOR_Instruction_Decoded:   gba_execute_EOR(ins)
	case GBA_LDM_Instruction_Decoded:   gba_execute_LDM(ins)
	case GBA_LDR_Instruction_Decoded:   gba_execute_LDR(ins)
	case GBA_LDRB_Instruction_Decoded:  gba_execute_LDRB(ins)
	case GBA_LDRBT_Instruction_Decoded: gba_execute_LDRBT(ins)
	case GBA_LDRH_Instruction_Decoded:  gba_execute_LDRH(ins)
	case GBA_LDRSB_Instruction_Decoded: gba_execute_LDRSB(ins)
	case GBA_LDRSH_Instruction_Decoded: gba_execute_LDRSH(ins)
	case GBA_LDRT_Instruction_Decoded:  gba_execute_LDRT(ins)
	case GBA_MLA_Instruction_Decoded:   gba_execute_MLA(ins)
	case GBA_MOV_Instruction_Decoded:   gba_execute_MOV(ins)
	case GBA_MRS_Instruction_Decoded:   gba_execute_MRS(ins)
	case GBA_MSR_Instruction_Decoded:   gba_execute_MSR(ins)
	case GBA_MUL_Instruction_Decoded:   gba_execute_MUL(ins)
	case GBA_MVN_Instruction_Decoded:   gba_execute_MVN(ins)
	case GBA_ORR_Instruction_Decoded:   gba_execute_ORR(ins)
	case GBA_RSB_Instruction_Decoded:   gba_execute_RSB(ins)
	case GBA_RSC_Instruction_Decoded:   gba_execute_RSC(ins)
	case GBA_SBC_Instruction_Decoded:   gba_execute_SBC(ins)
	case GBA_SMLAL_Instruction_Decoded: gba_execute_SMLAL(ins)
	case GBA_SMULL_Instruction_Decoded: gba_execute_SMULL(ins)
	case GBA_STM_Instruction_Decoded:   gba_execute_STM(ins)
	case GBA_STR_Instruction_Decoded:   gba_execute_STR(ins)
	case GBA_STRB_Instruction_Decoded:  gba_execute_STRB(ins)
	case GBA_STRBT_Instruction_Decoded: gba_execute_STRBT(ins)
	case GBA_STRH_Instruction_Decoded:  gba_execute_STRH(ins)
	case GBA_STRT_Instruction_Decoded:  gba_execute_STRT(ins)
	case GBA_SUB_Instruction_Decoded:   gba_execute_SUB(ins)
	case GBA_SWI_Instruction_Decoded:   gba_execute_SWI(ins)
	case GBA_SWP_Instruction_Decoded:   gba_execute_SWP(ins)
	case GBA_SWPB_Instruction_Decoded:  gba_execute_SWPB(ins)
	case GBA_TEQ_Instruction_Decoded:   gba_execute_TEQ(ins)
	case GBA_TST_Instruction_Decoded:   gba_execute_TST(ins)
	case GBA_UMLAL_Instruction_Decoded: gba_execute_UMLAL(ins)
	case GBA_UMULL_Instruction_Decoded: gba_execute_UMULL(ins)
	case GBA_Undefined_Instruction_Decoded: } }
@(private="file") gba_execute_ADC:: proc(ins: GBA_ADC_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
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
@(private="file") gba_execute_ADD:: proc(ins: GBA_ADD_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
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
@(private="file") gba_execute_AND:: proc(ins: GBA_AND_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	ins.destination^ = ins.operand & ins.shifter_operand
	if ins.set_condition_codes && ins.destination == gba_core.logical_registers.array[GBA_Logical_Register_Name.PC] {
		gba_pop_psr() }
	else if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destination^, 31, 1))
		cpsr.zero = (ins.destination^ == 0)
		cpsr.carry = ins.shifter_carry_out } }
@(private="file") gba_execute_B:: proc(ins: GBA_B_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	if ! gba_condition_passed(ins.cond) do return
	gba_set_pc(ins.target_address) }
@(private="file") gba_execute_BL:: proc(ins: GBA_BL_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	if ! gba_condition_passed(ins.cond) do return
	gba_core.logical_registers.array[GBA_Logical_Register_Name.LR]^ = ins.instruction_address + 4
	gba_set_pc(ins.target_address) }
@(private="file") gba_execute_BIC:: proc(ins: GBA_BIC_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	ins.destination^ = ins.operand & (~ ins.shifter_operand)
	if ins.set_condition_codes && ins.destination == gba_core.logical_registers.array[GBA_Logical_Register_Name.PC] {
		gba_pop_psr() }
	else if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destination^, 31, 1))
		cpsr.zero = (ins.destination^ == 0)
		cpsr.carry = ins.shifter_carry_out } }
@(private="file") gba_execute_BX:: proc(ins: GBA_BX_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	gba_set_pc(ins.target_address)
	cpsr.thumb_state = true }
@(private="file") gba_execute_CMN:: proc(ins: GBA_CMN_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	alu_out: i32 = ins.operand + ins.shifter_operand
	cpsr.negative = bool(bits.bitfield_extract(alu_out, 31, 1))
	cpsr.zero = (alu_out == 0)
	cpsr.carry = gba_carry_from_add(ins.operand, ins.shifter_operand)
	cpsr.overflow = gba_overflow_from_add(ins.operand, ins.shifter_operand) }
@(private="file") gba_execute_CMP:: proc(ins: GBA_CMP_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	alu_out: i32 = ins.operand - ins.shifter_operand
	cpsr.negative = bool(bits.bitfield_extract(alu_out, 31, 1))
	cpsr.zero = (alu_out == 0)
	cpsr.carry = gba_borrow_from(ins.operand, ins.shifter_operand)
	cpsr.overflow = gba_overflow_from_sub(ins.operand, ins.shifter_operand) }
@(private="file") gba_execute_EOR:: proc(ins: GBA_EOR_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	ins.destination^ = ins.operand ~ ins.shifter_operand
	if ins.set_condition_codes && ins.destination == gba_core.logical_registers.array[GBA_Logical_Register_Name.PC] {
		gba_pop_psr() }
	else if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destination^, 31, 1))
		cpsr.zero = (ins.destination^ == 0)
		cpsr.carry = ins.shifter_carry_out } }
@(private="file") gba_execute_LDM:: proc(ins: GBA_LDM_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
	if ! gba_condition_passed(ins.cond) do return
	address: = ins.start_address
	for register in GBA_Logical_Register_Name(0) ..< GBA_Logical_Register_Name(15) {
		if register in ins.destination_registers {
			gba_core.logical_registers.array[register]^ = memory_read_u32(address)
			address += 4 } }
	if ins.restore_status_register do gba_pop_psr() }
@(private="file") gba_execute_LDR:: proc(ins: GBA_LDR_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
	if ! gba_condition_passed(ins.cond) do return
	tail_bits: = bits.bitfield_extract(ins.address, 0, 2)
	switch tail_bits {
	case 0b00: ins.destination^ = memory_read_u32(ins.address)
	case 0b01: ins.destination^ = rotate_right(memory_read_u32(ins.address), 8)
	case 0b10: ins.destination^ = rotate_right(memory_read_u32(ins.address), 16)
	case 0b11: ins.destination^ = rotate_right(memory_read_u32(ins.address), 24) } }
@(private="file") gba_execute_LDRB:: proc(ins: GBA_LDRB_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
	if ! gba_condition_passed(ins.cond) do return
	ins.destination^ = cast(u32)memory_read_u8(ins.address) }
@(private="file") gba_execute_LDRBT:: proc(ins: GBA_LDRBT_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
	// TODO Do the write-back on all instructions. //
	if ! gba_condition_passed(ins.cond) do return
	ins.destination^ = cast(u32)memory_read_u8(ins.address) }
@(private="file") gba_execute_LDRH:: proc(ins: GBA_LDRH_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
	if ! gba_condition_passed(ins.cond) do return
	ins.destination^ = cast(u32)memory_read_u16(ins.address) }
@(private="file") gba_execute_LDRSB:: proc(ins: GBA_LDRSB_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
	if ! gba_condition_passed(ins.cond) do return
	ins.destination^ = transmute(u32)gba_sign_extend(cast(u32)memory_read_u8(ins.address), 8) }
@(private="file") gba_execute_LDRSH:: proc(ins: GBA_LDRSH_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
	if ! gba_condition_passed(ins.cond) do return
	ins.destination^ = transmute(u32)gba_sign_extend(cast(u32)memory_read_u16(ins.address), 16) }
@(private="file") gba_execute_LDRT:: proc(ins: GBA_LDRT_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
	if ! gba_condition_passed(ins.cond) do return
	tail_bits: = bits.bitfield_extract(ins.address, 0, 2)
	switch tail_bits {
	case 0b00: ins.destination^ = memory_read_u32(ins.address)
	case 0b01: ins.destination^ = rotate_right(memory_read_u32(ins.address), 8)
	case 0b10: ins.destination^ = rotate_right(memory_read_u32(ins.address), 16)
	case 0b11: ins.destination^ = rotate_right(memory_read_u32(ins.address), 24) } }
@(private="file") gba_execute_MLA:: proc(ins: GBA_MLA_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	ins.destination^ = transmute(u32)(ins.operand * ins.multiplicand + ins.addend)
	if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destination^, 31, 1))
		cpsr.zero = (ins.destination^ == 0)
		cpsr.carry = bool(rand.int_max(2)) } }
@(private="file") gba_execute_MOV:: proc(ins: GBA_MOV_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	if ins.set_condition_codes && ins.destination == gba_core.logical_registers.array[GBA_Logical_Register_Name.PC] {
		gba_pop_psr() }
	ins.destination^ = ins.shifter_operand
	if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destination^, 31, 1))
		cpsr.zero = (ins.destination^ == 0)
		cpsr.carry = ins.shifter_carry_out } }
@(private="file") gba_execute_MRS:: proc(ins: GBA_MRS_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
	if ! gba_condition_passed(ins.cond) do return
	ins.source^ = ins.destination^ }
@(private="file") gba_execute_MSR:: proc(ins: GBA_MSR_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
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
@(private="file") gba_execute_MUL:: proc(ins: GBA_MUL_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	ins.destination^ = transmute(u32)(ins.operand * ins.multiplicand)
	if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destination^, 31, 1))
		cpsr.zero = (ins.destination^ == 0)
		cpsr.carry = bool(rand.int_max(2)) } }
@(private="file") gba_execute_MVN:: proc(ins: GBA_MVN_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	ins.destination^ = ~ ins.shifter_operand
	if ins.set_condition_codes && ins.destination == gba_core.logical_registers.array[GBA_Logical_Register_Name.PC] {
		gba_pop_psr() }
	if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destination^, 31, 1))
		cpsr.zero = (ins.destination^ == 0)
		cpsr.carry = ins.shifter_carry_out } }
@(private="file") gba_execute_ORR:: proc(ins: GBA_ORR_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	ins.destination^ = ins.operand | ins.shifter_operand
	if ins.set_condition_codes && ins.destination == gba_core.logical_registers.array[GBA_Logical_Register_Name.PC] {
		gba_pop_psr() }
	else if ins.set_condition_codes {
		cpsr.negative = bool(bits.bitfield_extract(ins.destination^, 31, 1))
		cpsr.zero = (ins.destination^ == 0)
		cpsr.carry = ins.shifter_carry_out } }
@(private="file") gba_execute_RSB:: proc(ins: GBA_RSB_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
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
@(private="file") gba_execute_RSC:: proc(ins: GBA_RSC_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
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
@(private="file") gba_execute_SBC:: proc(ins: GBA_SBC_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
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
@(private="file") gba_execute_SMLAL:: proc(ins: GBA_SMLAL_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
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
@(private="file") gba_execute_SMULL:: proc(ins: GBA_SMULL_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
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
@(private="file") gba_execute_STM:: proc(ins: GBA_STM_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
	if ! gba_condition_passed(ins.cond) do return
	address: = ins.start_address
	for register in GBA_Logical_Register_Name(0) ..< GBA_Logical_Register_Name(15) {
		if register in ins.source_registers {
			memory_write_u32(address, gba_core.logical_registers.array[register]^)
			address += 4 } }
	if ins.restore_status_register do gba_pop_psr() }
@(private="file") gba_execute_STR:: proc(ins: GBA_STR_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
	if ! gba_condition_passed(ins.cond) do return
	memory_write_u32(ins.address, ins.source^) }
@(private="file") gba_execute_STRB:: proc(ins: GBA_STRB_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
	if ! gba_condition_passed(ins.cond) do return
	memory_write_u8(ins.address, cast(u8)(ins.source^ & 0xFF)) }
@(private="file") gba_execute_STRBT:: proc(ins: GBA_STRBT_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
	if ! gba_condition_passed(ins.cond) do return
	memory_write_u8(ins.address, cast(u8)(ins.source^ & 0xFF)) }
@(private="file") gba_execute_STRH:: proc(ins: GBA_STRH_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
	if ! gba_condition_passed(ins.cond) do return
	memory_write_u16(ins.address, cast(u16)(ins.source^ & 0xFFFF)) }
@(private="file") gba_execute_STRT:: proc(ins: GBA_STRT_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
	if ! gba_condition_passed(ins.cond) do return
	memory_write_u32(ins.address, ins.source^) }
@(private="file") gba_execute_SUB:: proc(ins: GBA_SUB_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
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
@(private="file") gba_execute_SWI:: proc(ins: GBA_SWI_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	gba_core.physical_registers.array[GBA_Physical_Register_Name.R14_SVC] = ins.instruction_address + 4
	gba_core.physical_registers.array[GBA_Physical_Register_Name.SPSR_SVC] = cast(u32)cpsr^
	cpsr^ = auto_cast bits.bitfield_insert(cast(u32)cpsr^, 0b010011, 0, 6)
	cpsr^ = auto_cast bits.bitfield_insert(cast(u32)cpsr^, 0b1, 7, 1)
	gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^ = 0x08 }
@(private="file") gba_execute_SWP:: proc(ins: GBA_SWP_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
	if ! gba_condition_passed(ins.cond) do return
	temp: u32 = memory_read_u32(ins.address)
	memory_write_u32(ins.address, ins.source_register^)
	ins.destination_register^ = temp }
@(private="file") gba_execute_SWPB:: proc(ins: GBA_SWPB_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
	if ! gba_condition_passed(ins.cond) do return
	temp: u8 = memory_read_u8(ins.address)
	memory_write_u8(ins.address, cast(u8)(ins.source_register^ & 0xFF))
	ins.destination_register^ = u32(temp) }
@(private="file") gba_execute_TEQ:: proc(ins: GBA_TEQ_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	alu_out: u32 = ins.operand ~ ins.shifter_operand
	cpsr.negative = bool(bits.bitfield_extract(alu_out, 31, 1))
	cpsr.zero = (alu_out == 0)
	cpsr.carry = ins.shifter_carry_out }
@(private="file") gba_execute_TST:: proc(ins: GBA_TST_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
	if ! gba_condition_passed(ins.cond) do return
	cpsr: = gba_get_cpsr()
	alu_out: u32 = ins.operand & ins.shifter_operand
	cpsr.negative = bool(bits.bitfield_extract(alu_out, 31, 1))
	cpsr.zero = (alu_out == 0)
	cpsr.carry = ins.shifter_carry_out }
@(private="file") gba_execute_UMLAL:: proc(ins: GBA_UMLAL_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
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
@(private="file") gba_execute_UMULL:: proc(ins: GBA_UMULL_Instruction_Decoded) {
	using state: ^State = cast(^State)context.user_ptr
	defer gba_increment_pc()
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