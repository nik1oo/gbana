package gbana
import "base:runtime"
import "core:fmt"
import "core:testing"
import "core:math/rand"


@(test)
test_main_clock:: proc(test_runner: ^testing.T) {
	init()
	for tick(n = 8) {
		if tick_index % 2 == 0 do testing.expect(test_runner, gba_core.main_clock.output == LOW)
		if tick_index % 2 == 1 do testing.expect(test_runner, gba_core.main_clock.output == HIGH) } }


@(test)
test_n_cycle:: proc(test_runner: ^testing.T) {
	init()
	tick(times = 3)
	// 2 //
	testing.expect(test_runner, tick_index == 2)
	gba_initiate_n_cycle(0b0)
	tick()
	// 3 //
	testing.expect(test_runner, tick_index == 3)
	testing.expect(test_runner, gba_core.memory_request.output == HIGH)
	testing.expect(test_runner, gba_core.sequential_cycle.output == LOW)
	testing.expect(test_runner, gba_core.data_in.enabled == false)
	tick()
	// 4 //
	testing.expect(test_runner, tick_index == 4)
	testing.expect(test_runner, gba_core.address.output == address)
	testing.expect(test_runner, gba_core.memory_request.output == HIGH)
	testing.expect(test_runner, gba_core.sequential_cycle.output == LOW)
	testing.expect(test_runner, gba_core.data_in.enabled == false)
	memory_initiate_n_cycle_response()
	tick()
	// 5 //
	testing.expect(test_runner, tick_index == 5)
	testing.expect(test_runner, gba_core.address.output == address)
	testing.expect(test_runner, gba_core.data_in.enabled == false)
	tick()
	// 6 //
	testing.expect(test_runner, tick_index == 6)
	testing.expect(test_runner, gba_core.data_in.enabled == true)
	tick()
	// 7 //
	testing.expect(test_runner, tick_index == 7)
	testing.expect(test_runner, gba_core.data_in.enabled == false) }


@(test)
test_s_cycle:: proc(test_runner: ^testing.T) {
	init()
	tick(times = 3)
	// 2 //
	testing.expect(test_runner, tick_index == 2)
	signal_put(&gba_core.memory_request, HIGH)
	signal_put(&gba_core.sequential_cycle, LOW)
	tick()
	// 3 //
	testing.expect(test_runner, tick_index == 3)
	testing.expect(test_runner, gba_core.memory_request.output == HIGH)
	testing.expect(test_runner, gba_core.sequential_cycle.output == LOW)
	testing.expect(test_runner, gba_core.data_in.enabled == false)
	address: u32 = 0b0
	signal_put(&gba_core.address, address)
	tick()
	// 4 //
	testing.expect(test_runner, tick_index == 4)
	testing.expect(test_runner, gba_core.address.output == address)
	testing.expect(test_runner, gba_core.memory_request.output == HIGH)
	testing.expect(test_runner, gba_core.sequential_cycle.output == LOW)
	testing.expect(test_runner, gba_core.data_in.enabled == false)
	signal_put(&gba_core.sequential_cycle, HIGH)
	tick()
	// 5 //
	testing.expect(test_runner, tick_index == 5)
	testing.expect(test_runner, gba_core.address.output == address)
	testing.expect(test_runner, gba_core.memory_request.output == HIGH)
	testing.expect(test_runner, gba_core.sequential_cycle.output == LOW)
	testing.expect(test_runner, gba_core.data_in.enabled == false)
	signal_put(&gba_core.sequential_cycle, HIGH)
	tick()
	// 6 //
	testing.expect(test_runner, tick_index == 6)
	testing.expect(test_runner, gba_core.address.output == address + 4)
	testing.expect(test_runner, gba_core.memory_request.output == HIGH)
	testing.expect(test_runner, gba_core.sequential_cycle.output == HIGH)
	testing.expect(test_runner, gba_core.data_in.enabled == true)
	tick()
	// 7 //
	testing.expect(test_runner, tick_index == 7)
	testing.expect(test_runner, gba_core.address.output == address + 4)
	testing.expect(test_runner, gba_core.memory_request.output == HIGH)
	testing.expect(test_runner, gba_core.sequential_cycle.output == HIGH)
	testing.expect(test_runner, gba_core.data_in.enabled == false)
	tick()
	// 8 //
	testing.expect(test_runner, tick_index == 8)
	testing.expect(test_runner, gba_core.address.output == address + 8)
	testing.expect(test_runner, gba_core.memory_request.output == HIGH)
	testing.expect(test_runner, gba_core.sequential_cycle.output == HIGH)
	testing.expect(test_runner, gba_core.data_in.enabled == true)
	tick()
	// 9 //
	testing.expect(test_runner, tick_index == 9)
	testing.expect(test_runner, gba_core.address.output == address + 8)
	testing.expect(test_runner, gba_core.memory_request.output == HIGH)
	testing.expect(test_runner, gba_core.sequential_cycle.output == HIGH)
	testing.expect(test_runner, gba_core.data_in.enabled == false)
	tick()
	// 10 //
	testing.expect(test_runner, tick_index == 10)
	testing.expect(test_runner, gba_core.address.output == address + 12)
	testing.expect(test_runner, gba_core.memory_request.output == HIGH)
	testing.expect(test_runner, gba_core.sequential_cycle.output == HIGH)
	testing.expect(test_runner, gba_core.data_in.enabled == true) }


@(test)
test_i_cycle:: proc(test_runner: ^testing.T) {
	init()
	tick(times = 3)
	// 2 //
	testing.expect(test_runner, tick_index == 2)
	signal_put(&gba_core.memory_request, LOW)
	signal_put(&gba_core.sequential_cycle, LOW)
	tick()
	// 3 //
	testing.expect(test_runner, tick_index == 3)
	testing.expect(test_runner, gba_core.memory_request.output == LOW)
	testing.expect(test_runner, gba_core.sequential_cycle.output == LOW) }


@(test)
test_merged_is_cycle:: proc(test_runner: ^testing.T) {
	init()
	tick(times = 3)
	// 2 //
	testing.expect(test_runner, tick_index == 2)
	signal_put(&gba_core.memory_request, LOW)
	signal_put(&gba_core.sequential_cycle, LOW)
	testing.expect(test_runner, gba_core.data_in.enabled == false)
	tick()
	// 3 //
	testing.expect(test_runner, tick_index == 3)
	testing.expect(test_runner, gba_core.memory_request.output == LOW)
	testing.expect(test_runner, gba_core.sequential_cycle.output == LOW)
	testing.expect(test_runner, gba_core.data_in.enabled == false)
	address: u32 = 0b0
	signal_put(&gba_core.address, address)
	tick()
	// 4 //
	testing.expect(test_runner, tick_index == 4)
	testing.expect(test_runner, gba_core.address.output == address)
	testing.expect(test_runner, gba_core.memory_request.output == LOW)
	testing.expect(test_runner, gba_core.sequential_cycle.output == LOW)
	testing.expect(test_runner, gba_core.data_in.enabled == false)
	signal_put(&gba_core.memory_request, HIGH)
	signal_put(&gba_core.sequential_cycle, HIGH)
	tick()
	// 5 //
	testing.expect(test_runner, tick_index == 5)
	testing.expect(test_runner, gba_core.address.output == address)
	testing.expect(test_runner, gba_core.memory_request.output == HIGH)
	testing.expect(test_runner, gba_core.sequential_cycle.output == HIGH)
	testing.expect(test_runner, gba_core.data_in.enabled == false)
	tick()
	// 6 //
	testing.expect(test_runner, tick_index == 6)
	testing.expect(test_runner, gba_core.memory_request.output == HIGH)
	testing.expect(test_runner, gba_core.sequential_cycle.output == HIGH)
	testing.expect(test_runner, gba_core.data_in.enabled == true)
	tick()
	// 7 //
	testing.expect(test_runner, tick_index == 7)
	testing.expect(test_runner, gba_core.data_in.enabled == false) }


@(test)
test_pipelined_addresses:: proc(test_runner: ^testing.T) {
	init()
	tick(times = 3)
	// 2 //
	testing.expect(test_runner, tick_index == 2)
	signal_put(&gba_core.memory_request, HIGH)
	signal_put(&gba_core.sequential_cycle, LOW)
	tick()
	// 3 //
	testing.expect(test_runner, tick_index == 3)
	testing.expect(test_runner, gba_core.memory_request.output == HIGH)
	testing.expect(test_runner, gba_core.sequential_cycle.output == LOW)
	address: u32 = 0b0
	signal_put(&gba_core.address, address)
	tick()
	// 4 //
	testing.expect(test_runner, tick_index == 4)
	testing.expect(test_runner, gba_core.memory_request.output == HIGH)
	testing.expect(test_runner, gba_core.sequential_cycle.output == LOW)
	testing.expect(test_runner, gba_core.address.output == address)
	tick()
	// 5 //
	testing.expect(test_runner, tick_index == 5)
	testing.expect(test_runner, gba_core.data_in.enabled == false)
	testing.expect(test_runner, gba_core.address.output == address)
	testing.expect(test_runner, gba_core.data_in.enabled == false)
	tick()
	// 6 //
	testing.expect(test_runner, tick_index == 6)
	testing.expect(test_runner, gba_core.data_in.enabled == true) }


@(test)
test_depipelined_addresses:: proc(test_runner: ^testing.T) {
	init()
	tick(times = 3)
	// 2 //
	testing.expect(test_runner, tick_index == 2)
	signal_put(&gba_core.memory_request, HIGH)
	signal_put(&gba_core.sequential_cycle, LOW)
	tick()
	// 3 //
	testing.expect(test_runner, tick_index == 3)
	testing.expect(test_runner, gba_core.memory_request.output == HIGH)
	testing.expect(test_runner, gba_core.sequential_cycle.output == LOW)
	tick()
	// 4 //
	testing.expect(test_runner, tick_index == 4)
	testing.expect(test_runner, gba_core.memory_request.output == HIGH)
	testing.expect(test_runner, gba_core.sequential_cycle.output == LOW)
	address: u32 = 0b0
	signal_put(&gba_core.address, address)
	tick()
	// 5 //
	testing.expect(test_runner, tick_index == 5)
	testing.expect(test_runner, gba_core.data_in.enabled == false)
	testing.expect(test_runner, gba_core.address.output == address)
	testing.expect(test_runner, gba_core.data_in.enabled == false)
	tick()
	// 6 //
	testing.expect(test_runner, tick_index == 6)
	testing.expect(test_runner, gba_core.data_in.enabled == true)
	testing.expect(test_runner, gba_core.address.output == address) }


@(test)
test_bidirectional_bus_cycle:: proc(test_runner: ^testing.T) {
	init()
	tick(times = 3)
	// 2 //
	testing.expect(test_runner, tick_index == 2)
	tick()
	// 3 //
	testing.expect(test_runner, tick_index == 3)
	testing.expect(test_runner, gba_core.data_in.enabled == false)
	tick()
	// 4 //
	testing.expect(test_runner, tick_index == 4)
	testing.expect(test_runner, gba_core.data_in.enabled == true)
	tick()
	// 5 //
	testing.expect(test_runner, tick_index == 5)
	testing.expect(test_runner, gba_core.data_in.enabled == true)
	tick()
	// 6 //
	testing.expect(test_runner, tick_index == 6)
	testing.expect(test_runner, gba_core.data_in.enabled == true)
	tick()
	// 7 //
	testing.expect(test_runner, tick_index == 7)
	testing.expect(test_runner, gba_core.data_in.enabled == false)
	tick()
	// 8 //
	testing.expect(test_runner, tick_index == 8)
	testing.expect(test_runner, gba_core.data_in.enabled == true)
	tick() }


@(test)
test_data_write_bus_cycle:: proc(test_runner: ^testing.T) {
	init()
	signal_put(&gba_core.read_write, GBA_Read_Write.WRITE)
	signal_put(&gba_core.output_enable, LOW)
	testing.expect(test_runner, gba_core.data_out.enabled == false)
	tick(times = 2)
	// 1 //
	testing.expect(test_runner, tick_index == 1)
	signal_put(&gba_core.read_write, GBA_Read_Write.WRITE)
	signal_put(&gba_core.output_enable, LOW)
	testing.expect(test_runner, gba_core.data_out.enabled == false)
	testing.expect(test_runner, gba_core.output_enable.output == LOW)
	address: u32 = 0b0
	signal_put(&gba_core.address, address)
	tick()
	// 2 //
	testing.expect(test_runner, tick_index == 2)
	testing.expect(test_runner, gba_core.address.output == address)
	testing.expect(test_runner, gba_core.read_write.output == .WRITE)
	testing.expect(test_runner, gba_core.output_enable.output == LOW)
	testing.expect(test_runner, gba_core.data_out.enabled == false)
	signal_put(&gba_core.output_enable, LOW)
	tick()
	// 3 //
	testing.expect(test_runner, tick_index == 3)
	testing.expect(test_runner, gba_core.address.output == address)
	testing.expect(test_runner, gba_core.read_write.output == .WRITE)
	testing.expect(test_runner, gba_core.output_enable.output == HIGH)
	testing.expect(test_runner, gba_core.data_out.enabled == true)
	tick()
	// 4 //
	testing.expect(test_runner, tick_index == 4)
	testing.expect(test_runner, gba_core.output_enable.output == HIGH)
	testing.expect(test_runner, gba_core.data_out.enabled == true)
	tick()
	// 5 //
	testing.expect(test_runner, tick_index == 5)
	testing.expect(test_runner, gba_core.output_enable.output == LOW)
	testing.expect(test_runner, gba_core.data_out.enabled == false) }


@(test)
test_halfword_bus_cycle:: proc(test_runner: ^testing.T) {
	init() }


@(test)
test_reset_sequence:: proc(test_runner: ^testing.T) {
	// test_runner._log_allocator = runtime.heap_allocator()
	init()
	address_sequence: [dynamic]u32
	tick()
	for tick(n = 8) {
		if tick_index <= 1 do testing.expect(test_runner, gba_core.reset.output == HIGH)
		else do testing.expect(test_runner, gba_core.reset.output == LOW)
		if tick_index <= 5 do testing.expect(test_runner, gba_core.memory_request.output == LOW)
		else do testing.expect(test_runner, gba_core.memory_request.output == HIGH)
		if tick_index <= 7 do testing.expect(test_runner, gba_core.sequential_cycle.output == LOW)
		else do testing.expect(test_runner, gba_core.sequential_cycle.output == HIGH)
		if tick_index <= 5 do testing.expect(test_runner, gba_core.execute_cycle.output == LOW)
		else do testing.expect(test_runner, gba_core.execute_cycle.output == HIGH)
		append(&address_sequence, gba_core.address.output) }
	for i in 0 ..< 6 {
		testing.expect(test_runner, address_sequence[1 + 2 * i] == address_sequence[2 + 2 * i]) }
	testing.expect(test_runner, (address_sequence[3] == address_sequence[1] + 2) || (address_sequence[3] == address_sequence[1] + 4))
	testing.expect(test_runner, (address_sequence[5] == address_sequence[3] + 2) || (address_sequence[5] == address_sequence[3] + 4))
	testing.expect(test_runner, address_sequence[7] == 0)
	testing.expect(test_runner, address_sequence[9] == address_sequence[7] + 4)
	testing.expect(test_runner, address_sequence[11] == address_sequence[9] + 4) }


test_GBA_ADC_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_ADD_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_AND_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_B_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_BL_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_BIC_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_BX_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_CDP_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_CMN_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_CMP_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_EOR_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_LDC_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_LDM_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_LDR_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_LDRB_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_LDRBT_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_LDRH_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_LDRSB_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_LDRSH_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_LDRT_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_MCR_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_MLA_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_MOV_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_MRC_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_MRS_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_MSR_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_MUL_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_MVN_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_ORR_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_RSB_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_RSC_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_SBC_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_SMLAL_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_SMULL_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_STM_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_STR_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_STRB_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_STRBT_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_STRH_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_STRT_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_SUB_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_SWI_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_SWP_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_SWPB_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_TEQ_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_TST_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_UMLAL_instruction:: proc(test_runner: ^testing.T) {
}

test_GBA_UMULL_instruction:: proc(test_runner: ^testing.T) {
}
