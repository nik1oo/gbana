package gbana
import "base:runtime"
import "core:fmt"
import "core:testing"
import "core:math/rand"
import "core:os"
import "core:log"


expect_tick:: proc(test_runner: ^testing.T, observed_value: uint, expected_value: uint, loc: = #caller_location) {
	testing.expect(test_runner, observed_value == expected_value, msg = fmt.tprint("[tick ", expected_value, "] ", "tick_index is ", observed_value, ", but should be ", expected_value, ".", sep = ""), loc = loc) }
expect_signal:: proc(test_runner: ^testing.T, tick: uint, signal_name: string, observed_value: $T, expected_value: T, loc: = #caller_location) {
	testing.expect(test_runner, observed_value == expected_value, msg = fmt.tprint("[tick ", tick, "] ", signal_name, " is ", observed_value, ", but should be ", expected_value, ".", sep = ""), loc = loc) }


LOW_HIGH: [2]bool = { LOW, HIGH }


@(test)
test_signal:: proc(test_runner: ^testing.T) {
	using state: State
	context = initialize_context(&state)
	allocate()
	signal: Signal(bool)
	// 0 //
	signal_init(name = "S", signal = &signal, latency = 1, callback = signal_stub_callback)
	signal_force(&signal, LOW)
	signal_put(&signal, HIGH)
	expect_signal(test_runner, 0, "S", signal.output, LOW)
	signal_tick(&signal)
	// 1 //
	expect_signal(test_runner, 1, "S", signal.output, HIGH)
	signal_put(&signal, LOW, latency_override = 1)
	signal_tick(&signal)
	// 2 //
	expect_signal(test_runner, 2, "S", signal.output, LOW)
	signal_put(&signal, HIGH, latency_override = 2)
	signal_tick(&signal)
	// 3 //
	expect_signal(test_runner, 3, "S", signal.output, LOW)
	signal_tick(&signal)
	// 4 //
	expect_signal(test_runner, 4, "S", signal.output, HIGH)
	signal_put(&signal, LOW, latency_override = 2)
	signal_put(&signal, HIGH, latency_override = 4)
	signal_tick(&signal)
	// 5 //
	expect_signal(test_runner, 5, "S", signal.output, HIGH)
	signal_tick(&signal)
	// 6 //
	expect_signal(test_runner, 6, "S", signal.output, LOW)
	signal_tick(&signal)
	// 7 //
	expect_signal(test_runner, 7, "S", signal.output, LOW)
	signal_tick(&signal)
	// 8 //
	expect_signal(test_runner, 8, "S", signal.output, HIGH)
	signal_tick(&signal) }


@(test)
test_main_clock:: proc(test_runner: ^testing.T) {
	// init()
	// for tick(n = 8) {
	// 	if tick_index % 2 == 0 do testing.expect(test_runner, gba_core.main_clock.output == LOW)
	// 	if tick_index % 2 == 1 do testing.expect(test_runner, gba_core.main_clock.output == HIGH) }
}


@(test)
test_memory_sequence:: proc(test_runner: ^testing.T) {
	using state: State
	k: = 1
	context = initialize_context(&state)
	allocate()
	// TODO What do I do with ABORT? //
	seq: = LOW
	// address: u32 = cast(u32)rand.int31_max(0x0e00ffff/4)
	address: u32 = 444
	dout: = rand.uint32()
	// for read_write in GBA_Read_Write {
	read_write: = GBA_Read_Write.READ
		initialize()
		tick(times = 3)
		// 2 //
		expect_tick(test_runner, tick_index, 2)
		gba_request_memory_sequence(sequential_cycle = LOW, read_write = read_write, address = address, data_out = dout)
		signal_put(&memory.address, address, latency_override = 2)
		signal_force(&memory.address, address)
		tick()
		expect_signal(test_runner, 2, "MREQ", memory.memory_request.output, HIGH)
		expect_signal(test_runner, 2, "SEQ", memory.sequential_cycle.output, LOW)
		// 3 //
		expect_tick(test_runner, tick_index, 3)
		tick()
		expect_signal(test_runner, 3, "MREQ", memory.memory_request.output, HIGH)
		expect_signal(test_runner, 3, "SEQ", memory.sequential_cycle.output, LOW)
		expect_signal(test_runner, 3, "RW", memory.read_write.output, read_write)
		// 4 //
		expect_tick(test_runner, tick_index, 4)
		memory_respond_memory_sequence(sequential_cycle = LOW, read_write = read_write, address = address)
		tick()
		expect_signal(test_runner, 4, "RW", memory.read_write.output, read_write)
		expect_signal(test_runner, 4, "A", memory.address.output, address)
		if read_write == .WRITE do expect_signal(test_runner, 4, "DOUT", memory.data_out.output, dout)
		expect_signal(test_runner, 4, "WAIT", gba_core.wait.output, LOW)
		// 5 //
		expect_tick(test_runner, tick_index, 5)
		tick()
		expect_signal(test_runner, 5, "A", memory.address.output, address)
		if read_write == .WRITE do expect_signal(test_runner, 5, "DOUT", memory.data_out.output, dout)
		else do expect_signal(test_runner, 5, "DIN", gba_core.data_in.output, memory_read_u32(address))
		// 6 //
		expect_tick(test_runner, tick_index, 6)
		tick()
		if read_write == .WRITE do expect_signal(test_runner, 6, "DOUT", memory.data_out.output, memory_read_u32(address))
	// }
	if testing.failed(test_runner) do log.info("\n", timeline_print(), sep = "") }


@(test)
test_n_cycle:: proc(test_runner: ^testing.T) {
	// address: = rand.int31_max(0x0e00ffff/4)
	// init()
	// for read_write in LOW ..= HIGH {
	// 	reinit()
	// 	tick(times = 3)
	// 	// 2 //
	// 	gba_request_n_cycle(read_write = read_write, address = address)
	// 	testing.expect(test_runner, tick_index == 2)
	// 	gba_initiate_n_cycle_request(address)
	// 	tick()
	// 	// 3 //
	// 	testing.expect(test_runner, tick_index == 3)
	// 	testing.expect(test_runner, memory.memory_request.output == HIGH)
	// 	testing.expect(test_runner, memory.sequential_cycle.output == LOW)
	// 	testing.expect(test_runner, gba_core.data_in.enabled == false)
	// 	tick()
	// 	// 4 //
	// 	testing.expect(test_runner, tick_index == 4)
	// 	testing.expect(test_runner, memory.address.output == address)
	// 	testing.expect(test_runner, memory.memory_request.output == HIGH)
	// 	testing.expect(test_runner, memory.sequential_cycle.output == LOW)
	// 	testing.expect(test_runner, gba_core.data_in.enabled == false)
	// 	memory_initiate_n_cycle_response()
	// 	tick()
	// 	// 5 //
	// 	testing.expect(test_runner, tick_index == 5)
	// 	testing.expect(test_runner, memory.address.output == address)
	// 	testing.expect(test_runner, gba_core.data_in.enabled == false)
	// 	tick()
	// 	// 6 //
	// 	testing.expect(test_runner, tick_index == 6)
	// 	testing.expect(test_runner, gba_core.data_in.enabled == true)
	// 	tick()
	// 	// 7 //
	// 	testing.expect(test_runner, tick_index == 7)
	// 	testing.expect(test_runner, gba_core.data_in.enabled == false) }
}


@(test)
test_s_cycle:: proc(test_runner: ^testing.T) {
	// init()
	// tick(times = 3)
	// // 2 //
	// testing.expect(test_runner, tick_index == 2)
	// signal_put(&memory.memory_request, HIGH)
	// signal_put(&memory.sequential_cycle, LOW)
	// tick()
	// // 3 //
	// testing.expect(test_runner, tick_index == 3)
	// testing.expect(test_runner, memory.memory_request.output == HIGH)
	// testing.expect(test_runner, memory.sequential_cycle.output == LOW)
	// testing.expect(test_runner, gba_core.data_in.enabled == false)
	// address: u32 = 0b0
	// signal_put(&memory.address, address)
	// tick()
	// // 4 //
	// testing.expect(test_runner, tick_index == 4)
	// testing.expect(test_runner, memory.address.output == address)
	// testing.expect(test_runner, memory.memory_request.output == HIGH)
	// testing.expect(test_runner, memory.sequential_cycle.output == LOW)
	// testing.expect(test_runner, gba_core.data_in.enabled == false)
	// signal_put(&memory.sequential_cycle, HIGH)
	// tick()
	// // 5 //
	// testing.expect(test_runner, tick_index == 5)
	// testing.expect(test_runner, memory.address.output == address)
	// testing.expect(test_runner, memory.memory_request.output == HIGH)
	// testing.expect(test_runner, memory.sequential_cycle.output == LOW)
	// testing.expect(test_runner, gba_core.data_in.enabled == false)
	// signal_put(&memory.sequential_cycle, HIGH)
	// tick()
	// // 6 //
	// testing.expect(test_runner, tick_index == 6)
	// testing.expect(test_runner, memory.address.output == address + 4)
	// testing.expect(test_runner, memory.memory_request.output == HIGH)
	// testing.expect(test_runner, memory.sequential_cycle.output == HIGH)
	// testing.expect(test_runner, gba_core.data_in.enabled == true)
	// tick()
	// // 7 //
	// testing.expect(test_runner, tick_index == 7)
	// testing.expect(test_runner, memory.address.output == address + 4)
	// testing.expect(test_runner, memory.memory_request.output == HIGH)
	// testing.expect(test_runner, memory.sequential_cycle.output == HIGH)
	// testing.expect(test_runner, gba_core.data_in.enabled == false)
	// tick()
	// // 8 //
	// testing.expect(test_runner, tick_index == 8)
	// testing.expect(test_runner, memory.address.output == address + 8)
	// testing.expect(test_runner, memory.memory_request.output == HIGH)
	// testing.expect(test_runner, memory.sequential_cycle.output == HIGH)
	// testing.expect(test_runner, gba_core.data_in.enabled == true)
	// tick()
	// // 9 //
	// testing.expect(test_runner, tick_index == 9)
	// testing.expect(test_runner, memory.address.output == address + 8)
	// testing.expect(test_runner, memory.memory_request.output == HIGH)
	// testing.expect(test_runner, memory.sequential_cycle.output == HIGH)
	// testing.expect(test_runner, gba_core.data_in.enabled == false)
	// tick()
	// // 10 //
	// testing.expect(test_runner, tick_index == 10)
	// testing.expect(test_runner, memory.address.output == address + 12)
	// testing.expect(test_runner, memory.memory_request.output == HIGH)
	// testing.expect(test_runner, memory.sequential_cycle.output == HIGH)
	// testing.expect(test_runner, gba_core.data_in.enabled == true)
}


@(test)
test_i_cycle:: proc(test_runner: ^testing.T) {
	// init()
	// tick(times = 3)
	// // 2 //
	// testing.expect(test_runner, tick_index == 2)
	// signal_put(&memory.memory_request, LOW)
	// signal_put(&memory.sequential_cycle, LOW)
	// tick()
	// // 3 //
	// testing.expect(test_runner, tick_index == 3)
	// testing.expect(test_runner, memory.memory_request.output == LOW)
	// testing.expect(test_runner, memory.sequential_cycle.output == LOW)
}


@(test)
test_merged_is_cycle:: proc(test_runner: ^testing.T) {
	// init()
	// tick(times = 3)
	// // 2 //
	// testing.expect(test_runner, tick_index == 2)
	// signal_put(&memory.memory_request, LOW)
	// signal_put(&memory.sequential_cycle, LOW)
	// testing.expect(test_runner, gba_core.data_in.enabled == false)
	// tick()
	// // 3 //
	// testing.expect(test_runner, tick_index == 3)
	// testing.expect(test_runner, memory.memory_request.output == LOW)
	// testing.expect(test_runner, memory.sequential_cycle.output == LOW)
	// testing.expect(test_runner, gba_core.data_in.enabled == false)
	// address: u32 = 0b0
	// signal_put(&memory.address, address)
	// tick()
	// // 4 //
	// testing.expect(test_runner, tick_index == 4)
	// testing.expect(test_runner, memory.address.output == address)
	// testing.expect(test_runner, memory.memory_request.output == LOW)
	// testing.expect(test_runner, memory.sequential_cycle.output == LOW)
	// testing.expect(test_runner, gba_core.data_in.enabled == false)
	// signal_put(&memory.memory_request, HIGH)
	// signal_put(&memory.sequential_cycle, HIGH)
	// tick()
	// // 5 //
	// testing.expect(test_runner, tick_index == 5)
	// testing.expect(test_runner, memory.address.output == address)
	// testing.expect(test_runner, memory.memory_request.output == HIGH)
	// testing.expect(test_runner, memory.sequential_cycle.output == HIGH)
	// testing.expect(test_runner, gba_core.data_in.enabled == false)
	// tick()
	// // 6 //
	// testing.expect(test_runner, tick_index == 6)
	// testing.expect(test_runner, memory.memory_request.output == HIGH)
	// testing.expect(test_runner, memory.sequential_cycle.output == HIGH)
	// testing.expect(test_runner, gba_core.data_in.enabled == true)
	// tick()
	// // 7 //
	// testing.expect(test_runner, tick_index == 7)
	// testing.expect(test_runner, gba_core.data_in.enabled == false)
}


@(test)
test_depipelined_addressing:: proc(test_runner: ^testing.T) {
	// init()
	// tick(times = 3)
	// // 2 //
	// testing.expect(test_runner, tick_index == 2)
	// signal_put(&memory.memory_request, HIGH)
	// signal_put(&memory.sequential_cycle, LOW)
	// tick()
	// // 3 //
	// testing.expect(test_runner, tick_index == 3)
	// testing.expect(test_runner, memory.memory_request.output == HIGH)
	// testing.expect(test_runner, memory.sequential_cycle.output == LOW)
	// tick()
	// // 4 //
	// testing.expect(test_runner, tick_index == 4)
	// testing.expect(test_runner, memory.memory_request.output == HIGH)
	// testing.expect(test_runner, memory.sequential_cycle.output == LOW)
	// address: u32 = 0b0
	// signal_put(&memory.address, address)
	// tick()
	// // 5 //
	// testing.expect(test_runner, tick_index == 5)
	// testing.expect(test_runner, gba_core.data_in.enabled == false)
	// testing.expect(test_runner, memory.address.output == address)
	// testing.expect(test_runner, gba_core.data_in.enabled == false)
	// tick()
	// // 6 //
	// testing.expect(test_runner, tick_index == 6)
	// testing.expect(test_runner, gba_core.data_in.enabled == true)
	// testing.expect(test_runner, memory.address.output == address)
}


@(test)
test_data_write_sequence:: proc(test_runner: ^testing.T) {
	// init()
	// signal_put(&memory.read_write, GBA_Read_Write.WRITE)
	// signal_put(&gba_core.output_enable, LOW)
	// testing.expect(test_runner, memory.data_out.enabled == false)
	// tick(times = 2)
	// // 1 //
	// testing.expect(test_runner, tick_index == 1)
	// signal_put(&memory.read_write, GBA_Read_Write.WRITE)
	// signal_put(&gba_core.output_enable, LOW)
	// testing.expect(test_runner, memory.data_out.enabled == false)
	// testing.expect(test_runner, gba_core.output_enable.output == LOW)
	// address: u32 = 0b0
	// signal_put(&memory.address, address)
	// tick()
	// // 2 //
	// testing.expect(test_runner, tick_index == 2)
	// testing.expect(test_runner, memory.address.output == address)
	// testing.expect(test_runner, memory.read_write.output == .WRITE)
	// testing.expect(test_runner, gba_core.output_enable.output == LOW)
	// testing.expect(test_runner, memory.data_out.enabled == false)
	// signal_put(&gba_core.output_enable, LOW)
	// tick()
	// // 3 //
	// testing.expect(test_runner, tick_index == 3)
	// testing.expect(test_runner, memory.address.output == address)
	// testing.expect(test_runner, memory.read_write.output == .WRITE)
	// testing.expect(test_runner, gba_core.output_enable.output == HIGH)
	// testing.expect(test_runner, memory.data_out.enabled == true)
	// tick()
	// // 4 //
	// testing.expect(test_runner, tick_index == 4)
	// testing.expect(test_runner, gba_core.output_enable.output == HIGH)
	// testing.expect(test_runner, memory.data_out.enabled == true)
	// tick()
	// // 5 //
	// testing.expect(test_runner, tick_index == 5)
	// testing.expect(test_runner, gba_core.output_enable.output == LOW)
	// testing.expect(test_runner, memory.data_out.enabled == false)
}


@(test)
test_data_read_sequence:: proc(test_runner: ^testing.T) { }


@(test)
test_byte_memory_sequence:: proc(test_runner: ^testing.T) { }


@(test)
test_halfword_memory_sequence:: proc(test_runner: ^testing.T) { }


@(test)
test_reset_sequence:: proc(test_runner: ^testing.T) {
	// test_runner._log_allocator = runtime.heap_allocator()
	// init()
	// address_sequence: [dynamic]u32
	// tick()
	// for tick(n = 8) {
	// 	if tick_index <= 1 do testing.expect(test_runner, gba_core.reset.output == HIGH)
	// 	else do testing.expect(test_runner, gba_core.reset.output == LOW)
	// 	if tick_index <= 5 do testing.expect(test_runner, memory.memory_request.output == LOW)
	// 	else do testing.expect(test_runner, memory.memory_request.output == HIGH)
	// 	if tick_index <= 7 do testing.expect(test_runner, memory.sequential_cycle.output == LOW)
	// 	else do testing.expect(test_runner, memory.sequential_cycle.output == HIGH)
	// 	if tick_index <= 5 do testing.expect(test_runner, gba_core.execute_cycle.output == LOW)
	// 	else do testing.expect(test_runner, gba_core.execute_cycle.output == HIGH)
	// 	append(&address_sequence, memory.address.output) }
	// for i in 0 ..< 6 {
	// 	testing.expect(test_runner, address_sequence[1 + 2 * i] == address_sequence[2 + 2 * i]) }
	// testing.expect(test_runner, (address_sequence[3] == address_sequence[1] + 2) || (address_sequence[3] == address_sequence[1] + 4))
	// testing.expect(test_runner, (address_sequence[5] == address_sequence[3] + 2) || (address_sequence[5] == address_sequence[3] + 4))
	// testing.expect(test_runner, address_sequence[7] == 0)
	// testing.expect(test_runner, address_sequence[9] == address_sequence[7] + 4)
	// testing.expect(test_runner, address_sequence[11] == address_sequence[9] + 4)
}


@(test)
test_general_timing:: proc(test_runner: ^testing.T) { }


@(test)
test_address_bus_control:: proc(test_runner: ^testing.T) { }


@(test)
test_data_bus_control:: proc(test_runner: ^testing.T) { }


@(test)
test_expection_control:: proc(test_runner: ^testing.T) { }


@(test)
test_address_pipeline_control:: proc(test_runner: ^testing.T) { }


@(test)
test_branch_and_branch_with_link_instruction_cycle:: proc(test_runner: ^testing.T) { }


@(test)
test_thumb_branch_with_link_instruction_cycle:: proc(test_runner: ^testing.T) { }


@(test)
test_branch_and_exchange_instruction_cycle:: proc(test_runner: ^testing.T) { }


@(test)
test_data_processing_instruction_cycle:: proc(test_runner: ^testing.T) {
	using state: State
	context = initialize_context(&state)
	allocate()
	alu: u32 = rand.uint32()
	destination_is_pc: bool = LOW
	shift_specified_by_register: bool = LOW
	initialize()
	tick()
	// 0 //
	expect_tick(test_runner, tick_index, 0)
	gba_request_data_processing_instruction_cycle(alu, destination_is_pc, shift_specified_by_register)
	memory_respond_data_processing_instruction_cycle(alu, destination_is_pc, shift_specified_by_register)
	tick()
	expect_signal(test_runner, 0, "MREQ", memory.memory_request.output, HIGH)
	expect_signal(test_runner, 0, "SEQ", memory.sequential_cycle.output, HIGH)
	expect_signal(test_runner, 0, "OPC", memory.op_code_fetch.output, HIGH)
	expect_signal(test_runner, 0, "RW", memory.read_write.output, GBA_Read_Write.READ)
	// 1 //
	expect_tick(test_runner, tick_index, 1)
	tick()
	expect_signal(test_runner, 1, "MREQ", memory.memory_request.output, HIGH)
	expect_signal(test_runner, 1, "SEQ", memory.sequential_cycle.output, HIGH)
	expect_signal(test_runner, 1, "OPC", memory.op_code_fetch.output, HIGH)
	expect_signal(test_runner, 1, "RW", memory.read_write.output, GBA_Read_Write.READ)
	pc: = gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^
	L: u32 = gba_core.executing_thumb.output ? 2 : 4
	data_in: = memory_read_u32(pc + 2 * L)
	expect_signal(test_runner, 1, "DIN", gba_core.data_in.output, data_in)
	if testing.failed(test_runner) do log.info("\n", timeline_print(), sep = "") }


@(test)
test_multiply_and_multiply_accumulate_instruction_cycle:: proc(test_runner: ^testing.T) { }


@(test)
test_load_register_instruction_cycle:: proc(test_runner: ^testing.T) { }


@(test)
test_store_register_instruction_cycle:: proc(test_runner: ^testing.T) { }


@(test)
test_load_multiple_register_instruction_cycle:: proc(test_runner: ^testing.T) { }


@(test)
test_store_multiple_register_instruction_cycle:: proc(test_runner: ^testing.T) { }


@(test)
test_data_swap_instruction_cycle:: proc(test_runner: ^testing.T) { }


@(test)
test_software_interrupt_and_expection_instruction_cycle:: proc(test_runner: ^testing.T) { }


@(test)
test_undefined_instruction_cycle:: proc(test_runner: ^testing.T) { }


@(test)
test_unexecuted_instruction_cycle:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_ADC_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_ADD_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_AND_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_B_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_BL_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_BIC_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_BX_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_CDP_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_CMN_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_CMP_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_EOR_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_LDC_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_LDM_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_LDR_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_LDRB_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_LDRBT_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_LDRH_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_LDRSB_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_LDRSH_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_LDRT_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_MCR_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_MLA_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_MOV_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_MRC_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_MRS_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_MSR_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_MUL_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_MVN_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_ORR_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_RSB_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_RSC_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_SBC_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_SMLAL_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_SMULL_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_STM_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_STR_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_STRB_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_STRBT_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_STRH_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_STRT_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_SUB_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_SWI_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_SWP_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_SWPB_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_TEQ_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_TST_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_UMLAL_instruction:: proc(test_runner: ^testing.T) { }


@(test)
test_GBA_UMULL_instruction:: proc(test_runner: ^testing.T) { }