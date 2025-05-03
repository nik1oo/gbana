package gbana
import "base:runtime"
import "core:fmt"
import "core:testing"
import "core:math/rand"
import "core:os"
import "core:log"


PRINT_ALL_TEST_TIMELINES:: #config(PRINT_ALL_TEST_TIMELINES, false)


// UTIL //
LOW_HIGH: [2]bool = { LOW, HIGH }
expect_tick:: proc(test_runner: ^testing.T, observed_value: uint, expected_value: uint, loc: = #caller_location) {
	testing.expect(test_runner, observed_value == expected_value, msg = fmt.tprint("[tick ", expected_value, "] ", "tick_index is ", observed_value, ", but should be ", expected_value, ".", sep = ""), loc = loc) }
expect_signal:: proc(test_runner: ^testing.T, tick: uint, signal_name: string, observed_value: $T, expected_value: T, loc: = #caller_location) {
	testing.expect(test_runner, observed_value == expected_value, msg = fmt.tprint("[tick ", tick, "] ", signal_name, " is ", observed_value, ", but should be ", expected_value, ".", sep = ""), loc = loc) }
generate_random_addresses:: proc() -> [2]u32 {
	valid_address: u32 = cast(u32)rand.int31_max(0x00003fff/4)
	invalid_address: u32 = max(0x0e010000, rand.uint32())
	return [2]u32{ valid_address, invalid_address } }
generate_random_VRAM_address:: proc() -> u32 {
	return VIDEO_RAM_RANGE[START] + cast(u32)rand.int31_max(i32(VIDEO_RAM_RANGE[END] - VIDEO_RAM_RANGE[START])) }
generate_random_EWRAM_address:: proc() -> u32 {
	return EXTERNAL_WORK_RAM_RANGE[START] + cast(u32)rand.int31_max(i32(EXTERNAL_WORK_RAM_RANGE[END] - EXTERNAL_WORK_RAM_RANGE[START])) }
generate_random_byte_bus_address:: proc(loc: = #caller_location) -> u32 {
	log.fatal("There is no byte-wide bus on the GBA.", location = loc)
	return 0 }


@(test)
test_signal:: proc(test_runner: ^testing.T) {
	using state: State
	context = initialize_context(&state)
	allocate()
	signal: Signal(bool)

	signal_init(name = "S", signal = &signal, latency = 1, callback = signal_stub_callback)
	signal_force(&signal, LOW)
	signal_put(&signal, HIGH)
	expect_signal(test_runner, 0, "S", signal.output, LOW)
	signal_tick(&signal)

	expect_signal(test_runner, 1, "S", signal.output, HIGH)
	signal_put(&signal, LOW, latency_override = 1)
	signal_tick(&signal)

	expect_signal(test_runner, 2, "S", signal.output, LOW)
	signal_put(&signal, HIGH, latency_override = 2)
	signal_tick(&signal)

	expect_signal(test_runner, 3, "S", signal.output, LOW)
	signal_tick(&signal)

	expect_signal(test_runner, 4, "S", signal.output, HIGH)
	signal_put(&signal, LOW, latency_override = 2)
	signal_put(&signal, HIGH, latency_override = 4)
	signal_tick(&signal)

	expect_signal(test_runner, 5, "S", signal.output, HIGH)
	signal_tick(&signal)

	expect_signal(test_runner, 6, "S", signal.output, LOW)
	signal_tick(&signal)

	expect_signal(test_runner, 7, "S", signal.output, LOW)
	signal_tick(&signal)

	expect_signal(test_runner, 8, "S", signal.output, HIGH)
	signal_tick(&signal) }


@(test)
test_main_clock:: proc(test_runner: ^testing.T) {
	using state: State
	context = initialize_context(&state)
	allocate()

	initialize()
	tick()
	for tick(n = 8) {
		if tick_index % 2 == 1 do testing.expect(test_runner, gba_core.main_clock.output == LOW)
		if tick_index % 2 == 0 do testing.expect(test_runner, gba_core.main_clock.output == HIGH) }
	if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = "Main Clock"), sep = "") }


@(test)
test_memory_sequence:: proc(test_runner: ^testing.T) {
	using state: State
	context = initialize_context(&state)
	allocate()
	addresses: = generate_random_addresses()
	data_out: = rand.uint32()

	for read_write in Memory_Read_Write do for address in addresses {
		initialize()
		tick(times = 4)

		expect_tick(test_runner, tick_index, 3)
		gba_request_memory_sequence(sequential_cycle = LOW, read_write = read_write, address = address, data_out = data_out)
		expect_signal(test_runner, 3, "MREQ", memory.memory_request.output, HIGH)
		expect_signal(test_runner, 3, "SEQ", memory.sequential_cycle.output, LOW)
		tick()

		expect_tick(test_runner, tick_index, 4)
		expect_signal(test_runner, 4, "MREQ", memory.memory_request.output, HIGH)
		expect_signal(test_runner, 4, "SEQ", memory.sequential_cycle.output, LOW)
		expect_signal(test_runner, 4, "RW", memory.read_write.output, read_write)
		tick()

		expect_tick(test_runner, tick_index, 5)
		memory_respond_memory_sequence(sequential_cycle = LOW, read_write = read_write, address = address)
		expect_signal(test_runner, 5, "RW", memory.read_write.output, read_write)
		expect_signal(test_runner, 5, "A", memory.address.output, address)
		if read_write == .WRITE do expect_signal(test_runner, 5, "DOUT", memory.data_out.output, data_out)
		expect_signal(test_runner, 5, "WAIT", gba_core.wait.output, LOW)
		tick()

		expect_tick(test_runner, tick_index, 6)
		expect_signal(test_runner, 6, "A", memory.address.output, address)
		if read_write == .WRITE do expect_signal(test_runner, 6, "DOUT", memory.data_out.output, data_out)
		else do expect_signal(test_runner, 6, "DIN", gba_core.data_in.output, memory_read_u32(address))
		tick()

		expect_tick(test_runner, tick_index, 7)
		if read_write == .WRITE do expect_signal(test_runner, 7, "DOUT", memory.data_out.output, data_out)
		if address == addresses[0] do expect_signal(test_runner, 7, "ABORT", gba_core.abort.output, LOW)
		else do expect_signal(test_runner, 7, "ABORT", gba_core.abort.output, HIGH)
		tick()

		if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = "Memory Sequence"), sep = "") } }


@(test)
test_n_cycle:: proc(test_runner: ^testing.T) {
	using state: State
	context = initialize_context(&state)
	allocate()
	addresses: = generate_random_addresses()
	data_out: = rand.uint32()

	for read_write in Memory_Read_Write do for address in addresses {
		initialize()
		tick(times = 4)

		expect_tick(test_runner, tick_index, 3)
		gba_request_memory_sequence(sequential_cycle = LOW, read_write = read_write, address = address, data_out = data_out)
		expect_signal(test_runner, 3, "MREQ", memory.memory_request.output, HIGH)
		expect_signal(test_runner, 3, "SEQ", memory.sequential_cycle.output, LOW)
		tick()

		expect_tick(test_runner, tick_index, 4)
		expect_signal(test_runner, 4, "MREQ", memory.memory_request.output, HIGH)
		expect_signal(test_runner, 4, "SEQ", memory.sequential_cycle.output, LOW)
		expect_signal(test_runner, 4, "RW", memory.read_write.output, read_write)
		tick()

		expect_tick(test_runner, tick_index, 5)
		memory_respond_n_cycle(read_write = read_write, address = address)
		expect_signal(test_runner, 5, "RW", memory.read_write.output, read_write)
		expect_signal(test_runner, 5, "A", memory.address.output, address)
		if read_write == .WRITE do expect_signal(test_runner, 5, "DOUT", memory.data_out.output, data_out)
		expect_signal(test_runner, 5, "WAIT", gba_core.wait.output, LOW)
		tick()

		expect_tick(test_runner, tick_index, 6)
		expect_signal(test_runner, 6, "A", memory.address.output, address)
		if read_write == .WRITE do expect_signal(test_runner, 6, "DOUT", memory.data_out.output, data_out)
		else do expect_signal(test_runner, 6, "DIN", gba_core.data_in.output, memory_read_u32(address))
		tick()

		expect_tick(test_runner, tick_index, 7)
		if read_write == .WRITE do expect_signal(test_runner, 7, "DOUT", memory.data_out.output, data_out)
		if address == addresses[0] do expect_signal(test_runner, 7, "ABORT", gba_core.abort.output, LOW)
		else do expect_signal(test_runner, 7, "ABORT", gba_core.abort.output, HIGH)
		tick()

		if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = "N-Cycle"), sep = "") } }


@(test)
test_s_cycle:: proc(test_runner: ^testing.T) {
	using state: State
	context = initialize_context(&state)
	allocate()
	addresses: = generate_random_addresses()
	address: = addresses[0]
	data_out: = rand.uint32()

	for read_write in Memory_Read_Write {
		initialize()
		tick(times = 4)

		expect_tick(test_runner, tick_index, 3)
		gba_request_memory_sequence(sequential_cycle = LOW, read_write = read_write, address = address, data_out = data_out)
		expect_signal(test_runner, 3, "MREQ", memory.memory_request.output, HIGH)
		expect_signal(test_runner, 3, "SEQ", memory.sequential_cycle.output, LOW)
		tick()

		expect_tick(test_runner, tick_index, 4)
		expect_signal(test_runner, 4, "MREQ", memory.memory_request.output, HIGH)
		expect_signal(test_runner, 4, "SEQ", memory.sequential_cycle.output, LOW)
		tick()

		expect_tick(test_runner, tick_index, 5)
		gba_request_memory_sequence(sequential_cycle = HIGH, read_write = read_write, address = address + 0, data_out = data_out)
		memory_respond_n_cycle(read_write = read_write, address = address)
		expect_signal(test_runner, 5, "MREQ", memory.memory_request.output, HIGH)
		expect_signal(test_runner, 5, "SEQ", memory.sequential_cycle.output, HIGH)
		expect_signal(test_runner, 5, "A", memory.address.output, address)
		if read_write == .WRITE do expect_signal(test_runner, 5, "DOUT", memory.data_out.output, data_out)
		tick()

		expect_tick(test_runner, tick_index, 6)
		expect_signal(test_runner, 6, "MREQ", memory.memory_request.output, HIGH)
		expect_signal(test_runner, 6, "SEQ", memory.sequential_cycle.output, HIGH)
		expect_signal(test_runner, 6, "A", memory.address.output, address)
		if read_write == .WRITE do expect_signal(test_runner, 6, "DOUT", memory.data_out.output, data_out)
		else do expect_signal(test_runner, 6, "DIN", gba_core.data_in.output, memory_read_u32(address))
		tick()

		expect_tick(test_runner, tick_index, 7)
		gba_request_memory_sequence(sequential_cycle = HIGH, read_write = read_write, address = address + 4, data_out = data_out)
		memory_respond_s_cycle(read_write = read_write, address = address)
		expect_signal(test_runner, 7, "MREQ", memory.memory_request.output, HIGH)
		expect_signal(test_runner, 7, "SEQ", memory.sequential_cycle.output, HIGH)
		expect_signal(test_runner, 7, "A", memory.address.output, address)
		if read_write == .WRITE do expect_signal(test_runner, 7, "DOUT", memory.data_out.output, data_out)
		tick()

		expect_tick(test_runner, tick_index, 8)
		expect_signal(test_runner, 8, "MREQ", memory.memory_request.output, HIGH)
		expect_signal(test_runner, 8, "SEQ", memory.sequential_cycle.output, HIGH)
		expect_signal(test_runner, 8, "A", memory.address.output, address)
		if read_write == .WRITE do expect_signal(test_runner, 8, "DOUT", memory.data_out.output, data_out)
		else do expect_signal(test_runner, 8, "DIN", gba_core.data_in.output, memory_read_u32(address))
		tick()

		expect_tick(test_runner, tick_index, 9)
		memory_respond_s_cycle(read_write = read_write, address = address)
		tick()

		if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = "S-Cycle"), sep = "") } }


@(test)
test_i_cycle:: proc(test_runner: ^testing.T) {
	using state: State
	context = initialize_context(&state)
	allocate()

	initialize()
	tick(times = 2)

	expect_tick(test_runner, tick_index, 1)
	gba_initiate_i_cycle()
	expect_signal(test_runner, 1, "MREQ", memory.memory_request.output, LOW)
	expect_signal(test_runner, 1, "SEQ", memory.sequential_cycle.output, LOW)
	tick()

	expect_tick(test_runner, tick_index, 2)
	expect_signal(test_runner, 2, "MREQ", memory.memory_request.output, LOW)
	expect_signal(test_runner, 2, "SEQ", memory.sequential_cycle.output, LOW)
	tick()

	if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = "I-Cycle"), sep = "") }


@(test)
test_merged_is_cycle:: proc(test_runner: ^testing.T) {
	using state: State
	context = initialize_context(&state)
	allocate()
	addresses: = generate_random_addresses()
	address: = addresses[0]
	data_out: = rand.uint32()
	read_write: = Memory_Read_Write.READ

	initialize()
	tick(times = 4)

	expect_tick(test_runner, tick_index, 3)
	gba_request_merged_is_cycle(read_write = read_write, address = address, data_out = data_out)
	expect_signal(test_runner, 3, "MREQ", memory.memory_request.output, LOW)
	expect_signal(test_runner, 3, "SEQ", memory.sequential_cycle.output, LOW)
	tick()

	expect_tick(test_runner, tick_index, 4)
	expect_signal(test_runner, 4, "MREQ", memory.memory_request.output, LOW)
	expect_signal(test_runner, 4, "SEQ", memory.sequential_cycle.output, LOW)
	tick()

	expect_tick(test_runner, tick_index, 5)
	memory_respond_merged_is_cycle(read_write = read_write, address = address)
	expect_signal(test_runner, 5, "MREQ", memory.memory_request.output, HIGH)
	expect_signal(test_runner, 5, "SEQ", memory.sequential_cycle.output, HIGH)
	expect_signal(test_runner, 5, "A", memory.address.output, address)
	if read_write == .WRITE do expect_signal(test_runner, 5, "DOUT", memory.data_out.output, data_out)
	tick()

	expect_tick(test_runner, tick_index, 6)
	expect_signal(test_runner, 6, "MREQ", memory.memory_request.output, HIGH)
	expect_signal(test_runner, 6, "SEQ", memory.sequential_cycle.output, HIGH)
	expect_signal(test_runner, 6, "A", memory.address.output, address)
	if read_write == .WRITE do expect_signal(test_runner, 6, "DOUT", memory.data_out.output, data_out)
	else do expect_signal(test_runner, 6, "DIN", gba_core.data_in.output, memory_read_u32(address))
	tick()

	if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = "Merged IS-Cycle"), sep = "") }


@(test)
test_depipelined_addressing:: proc(test_runner: ^testing.T) {
	using state: State
	context = initialize_context(&state)
	allocate()
	addresses: = generate_random_addresses()
	address: = addresses[0]

	initialize()
	tick(times = 4)

	expect_tick(test_runner, tick_index, 3)
	signal_force(&memory.memory_request, HIGH)
	signal_force(&memory.sequential_cycle, LOW)
	tick()

	expect_tick(test_runner, tick_index, 4)
	expect_signal(test_runner, 4, "MREQ", memory.memory_request.output, HIGH)
	expect_signal(test_runner, 4, "SEQ", memory.sequential_cycle.output, LOW)
	tick()

	expect_tick(test_runner, tick_index, 5)
	expect_signal(test_runner, 5, "MREQ", memory.memory_request.output, HIGH)
	expect_signal(test_runner, 5, "SEQ", memory.sequential_cycle.output, LOW)
	signal_force(&memory.address, address)
	tick()

	expect_tick(test_runner, tick_index, 6)
	expect_signal(test_runner, 6, "A", memory.address.output, address)
	tick()

	expect_tick(test_runner, tick_index, 7)
	expect_signal(test_runner, 7, "A", memory.address.output, address)

	if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = "Depipelined Addressing"), sep = "") }


@(test)
test_data_write_sequence:: proc(test_runner: ^testing.T) {
	using state: State
	context = initialize_context(&state)
	allocate()
	addresses: = generate_random_addresses()
	data_out: = rand.uint32()

	for address in addresses {
		initialize()
		tick(times = 4)

		expect_tick(test_runner, tick_index, 3)
		gba_request_data_write_cycle(sequential_cycle = LOW, address = address, data_out = data_out)
		expect_signal(test_runner, 3, "MREQ", memory.memory_request.output, HIGH)
		expect_signal(test_runner, 3, "SEQ", memory.sequential_cycle.output, LOW)
		tick()

		expect_tick(test_runner, tick_index, 4)
		expect_signal(test_runner, 4, "MREQ", memory.memory_request.output, HIGH)
		expect_signal(test_runner, 4, "SEQ", memory.sequential_cycle.output, LOW)
		expect_signal(test_runner, 4, "RW", memory.read_write.output, Memory_Read_Write.WRITE)
		tick()

		expect_tick(test_runner, tick_index, 5)
		memory_respond_data_write_cycle(sequential_cycle = LOW, address = address)
		expect_signal(test_runner, 5, "RW", memory.read_write.output, Memory_Read_Write.WRITE)
		expect_signal(test_runner, 5, "A", memory.address.output, address)
		expect_signal(test_runner, 5, "DOUT", memory.data_out.output, data_out)
		expect_signal(test_runner, 5, "WAIT", gba_core.wait.output, LOW)
		tick()

		expect_tick(test_runner, tick_index, 6)
		expect_signal(test_runner, 6, "A", memory.address.output, address)
		expect_signal(test_runner, 6, "DOUT", memory.data_out.output, data_out)
		tick()

		expect_tick(test_runner, tick_index, 7)
		expect_signal(test_runner, 7, "DOUT", memory.data_out.output, data_out)
		if address == addresses[0] do expect_signal(test_runner, 7, "ABORT", gba_core.abort.output, LOW)
		else do expect_signal(test_runner, 7, "ABORT", gba_core.abort.output, HIGH)
		tick()

		if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = "Data Write Sequence"), sep = "") } }


@(test)
test_data_read_sequence:: proc(test_runner: ^testing.T) {
	using state: State
	context = initialize_context(&state)
	allocate()
	addresses: = generate_random_addresses()

	for address in addresses {
		initialize()
		tick(times = 4)

		expect_tick(test_runner, tick_index, 3)
		gba_request_data_read_cycle(sequential_cycle = LOW, address = address)
		expect_signal(test_runner, 3, "MREQ", memory.memory_request.output, HIGH)
		expect_signal(test_runner, 3, "SEQ", memory.sequential_cycle.output, LOW)
		tick()

		expect_tick(test_runner, tick_index, 4)
		expect_signal(test_runner, 4, "MREQ", memory.memory_request.output, HIGH)
		expect_signal(test_runner, 4, "SEQ", memory.sequential_cycle.output, LOW)
		expect_signal(test_runner, 4, "RW", memory.read_write.output, Memory_Read_Write.READ)
		tick()

		expect_tick(test_runner, tick_index, 5)
		memory_respond_data_read_cycle(sequential_cycle = LOW, address = address)
		expect_signal(test_runner, 5, "RW", memory.read_write.output, Memory_Read_Write.READ)
		expect_signal(test_runner, 5, "A", memory.address.output, address)
		expect_signal(test_runner, 5, "WAIT", gba_core.wait.output, LOW)
		tick()

		expect_tick(test_runner, tick_index, 6)
		expect_signal(test_runner, 6, "A", memory.address.output, address)
		expect_signal(test_runner, 6, "DIN", gba_core.data_in.output, memory_read_u32(address))
		tick()

		expect_tick(test_runner, tick_index, 7)
		if address == addresses[0] do expect_signal(test_runner, 7, "ABORT", gba_core.abort.output, LOW)
		else do expect_signal(test_runner, 7, "ABORT", gba_core.abort.output, HIGH)
		tick()

		if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = "Data Read Sequence"), sep = "") } }


@(test)
test_delayed_memory_sequence:: proc(test_runner: ^testing.T) {
	using state: State
	context = initialize_context(&state)
	allocate()
	address: = generate_random_EWRAM_address()
	data_out: = rand.uint32()

	for read_write in Memory_Read_Write {
		initialize()
		tick(times = 4)

		expect_tick(test_runner, tick_index, 3)
		gba_request_memory_sequence(sequential_cycle = LOW, read_write = read_write, address = address, data_out = data_out, memory_access_size = .HALFWORD)
		expect_signal(test_runner, 3, "MREQ", memory.memory_request.output, HIGH)
		expect_signal(test_runner, 3, "SEQ", memory.sequential_cycle.output, LOW)
		tick()

		expect_tick(test_runner, tick_index, 4)
		expect_signal(test_runner, 4, "MREQ", memory.memory_request.output, HIGH)
		expect_signal(test_runner, 4, "SEQ", memory.sequential_cycle.output, LOW)
		expect_signal(test_runner, 4, "RW", memory.read_write.output, read_write)
		tick()

		memory_respond_memory_sequence(sequential_cycle = LOW, read_write = read_write, address = address, memory_access_size = .HALFWORD)
		wait_cycles: uint = uint(memory_bus_latency_from_address(address, 4)) - 1
		for i in 0 ..< wait_cycles {
			expect_signal(test_runner, 5 + 2 * i, "WAIT", gba_core.wait.output, HIGH)
			tick()

			expect_signal(test_runner, 5 + 2 * i + 1, "WAIT", gba_core.wait.output, HIGH)
			tick() }

		expect_tick(test_runner, tick_index, 5 + 2 * wait_cycles)
		expect_signal(test_runner, 5 + 2 * wait_cycles, "RW", memory.read_write.output, read_write)
		expect_signal(test_runner, 5 + 2 * wait_cycles, "A", memory.address.output, address)
		if read_write == .WRITE do expect_signal(test_runner, 5 + 2 * wait_cycles, "DOUT", memory.data_out.output, data_out)
		expect_signal(test_runner, 5 + 2 * wait_cycles, "WAIT", gba_core.wait.output, LOW)
		tick()

		expect_tick(test_runner, tick_index, 6 + 2 * wait_cycles)
		expect_signal(test_runner, 6 + 2 * wait_cycles, "A", memory.address.output, address)
		if read_write == .WRITE do expect_signal(test_runner, 6 + 2 * wait_cycles, "DOUT", memory.data_out.output, data_out)
		else do expect_signal(test_runner, 6 + 2 * wait_cycles, "DIN", gba_core.data_in.output, memory_read_u32(address))
		tick()

		expect_tick(test_runner, tick_index, 7 + 2 * wait_cycles)
		if read_write == .WRITE do expect_signal(test_runner, 7 + 2 * wait_cycles, "DOUT", memory.data_out.output, data_out)
		tick()

		if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = "Delayed Memory Sequence"), sep = "") } }


@(test)
test_halfword_memory_sequence:: proc(test_runner: ^testing.T) {
	using state: State
	context = initialize_context(&state)
	allocate()
	address: = generate_random_VRAM_address()
	data_out: = rand.uint32()

	for read_write in Memory_Read_Write {
		initialize()
		tick(times = 4)

		expect_tick(test_runner, tick_index, 3)
		gba_request_memory_sequence(sequential_cycle = LOW, read_write = read_write, address = address, data_out = data_out)
		expect_signal(test_runner, 3, "MREQ", memory.memory_request.output, HIGH)
		expect_signal(test_runner, 3, "SEQ", memory.sequential_cycle.output, LOW)
		tick()

		expect_tick(test_runner, tick_index, 4)
		expect_signal(test_runner, 4, "MREQ", memory.memory_request.output, HIGH)
		expect_signal(test_runner, 4, "SEQ", memory.sequential_cycle.output, LOW)
		expect_signal(test_runner, 4, "RW", memory.read_write.output, read_write)
		tick()

		expect_tick(test_runner, tick_index, 5)
		memory_respond_memory_sequence(sequential_cycle = LOW, read_write = read_write, address = address)
		// VRAM has a 16-bit-wide bus and an access latency of 2 cycles for word-sized requests. //
		for i in 0 ..< 4 {
			expect_signal(test_runner, 5 + uint(i), "WAIT", gba_core.wait.output, HIGH)
			tick() }

		expect_signal(test_runner, 9, "WAIT", gba_core.wait.output, LOW)
		expect_signal(test_runner, 9, "RW", memory.read_write.output, read_write)
		expect_signal(test_runner, 9, "A", memory.address.output, address)
		if read_write == .WRITE do expect_signal(test_runner, 9, "DOUT", memory.data_out.output, data_out)
		expect_signal(test_runner, 9, "WAIT", gba_core.wait.output, LOW)
		tick()

		expect_tick(test_runner, tick_index, 10)
		expect_signal(test_runner, 10, "A", memory.address.output, address)
		if read_write == .WRITE do expect_signal(test_runner, 10, "DOUT", memory.data_out.output, data_out)
		else do expect_signal(test_runner, 10, "DIN", gba_core.data_in.output, memory_read_u32(address))
		tick()

		expect_tick(test_runner, tick_index, 11)
		if read_write == .WRITE do expect_signal(test_runner, 11, "DOUT", memory.data_out.output, data_out)
		expect_signal(test_runner, 11, "ABORT", gba_core.abort.output, LOW)
		tick()

		if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = "Halfword Memory Sequence"), sep = "") } }


@(test)
test_byte_memory_sequence:: proc(test_runner: ^testing.T) {
	/* Byte-wide-bus memory exists only on cartridges with SRAM memory. GBANA emulates a cartridge with Flash memory. */ }


@(test)
test_reset_sequence:: proc(test_runner: ^testing.T) {
	using state: State
	context = initialize_context(&state)
	allocate()
	initialize()
	tick(times = 2)

	gba_request_reset_sequence()
	memory_respond_reset_sequence()

	for i in uint(1) ..= uint(2) {
		expect_tick(test_runner, tick_index, i)
		expect_signal(test_runner, i, "RESET", gba_core.reset.output, HIGH)
		expect_signal(test_runner, i, "MREQ", memory.memory_request.output, LOW)
		expect_signal(test_runner, i, "SEQ", memory.sequential_cycle.output, LOW)
		expect_signal(test_runner, i, "EXEC", gba_core.execute_cycle.output, LOW)
		tick() }

	for i in uint(3) ..= uint(6) {
		expect_tick(test_runner, tick_index, i)
		expect_signal(test_runner, i, "RESET", gba_core.reset.output, LOW)
		expect_signal(test_runner, i, "MREQ", memory.memory_request.output, LOW)
		expect_signal(test_runner, i, "SEQ", memory.sequential_cycle.output, LOW)
		expect_signal(test_runner, i, "EXEC", gba_core.execute_cycle.output, LOW)
		tick() }

	for i in uint(7) ..= uint(8) {
		expect_tick(test_runner, tick_index, i)
		expect_signal(test_runner, i, "RESET", gba_core.reset.output, LOW)
		expect_signal(test_runner, i, "MREQ", memory.memory_request.output, HIGH)
		expect_signal(test_runner, i, "SEQ", memory.sequential_cycle.output, LOW)
		expect_signal(test_runner, i, "EXEC", gba_core.execute_cycle.output, HIGH)
		tick() }

	for i in uint(9) ..= uint(10) {
		expect_tick(test_runner, tick_index, i)
		expect_signal(test_runner, i, "RESET", gba_core.reset.output, LOW)
		expect_signal(test_runner, i, "MREQ", memory.memory_request.output, HIGH)
		expect_signal(test_runner, i, "SEQ", memory.sequential_cycle.output, HIGH)
		expect_signal(test_runner, i, "EXEC", gba_core.execute_cycle.output, HIGH)
		if tick_index % 2 == 0 do expect_signal(test_runner, 10, "DIN", gba_core.data_in.output, memory_read_u32(0))
		tick() }

	if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = "Reset Sequence"), sep = "") }


@(test)
test_general_timing:: proc(test_runner: ^testing.T) {
	using state: State
	context = initialize_context(&state)
	allocate()
	initialize()
	tick()

	expect_tick(test_runner, tick_index, 0)
	signal_put(&memory.memory_request, HIGH, latency_override = 1)
	signal_put(&memory.sequential_cycle, HIGH, latency_override = 1)
	signal_put(&gba_core.execute_cycle, HIGH, latency_override = 1)
	signal_put(&memory.address, 0b0, latency_override = 1)
	signal_put(&gba_core.big_endian, HIGH, latency_override = 1)
	signal_put(&gba_core.synchronous_interrupts_enable, HIGH, latency_override = 1)
	signal_put(&memory.read_write, Memory_Read_Write.READ, latency_override = 2)
	signal_put(&memory.memory_access_size, Memory_Access_Size.WORD, latency_override = 2)
	signal_put(&memory.lock, HIGH, latency_override = 2)
	signal_put(&gba_core.processor_mode, GBA_Processor_Mode.System, latency_override = 2)
	signal_put(&gba_core.executing_thumb, HIGH, latency_override = 2)
	signal_put(&memory.op_code_fetch, HIGH, latency_override = 2)
	signal_put(&gba_core.synchronous_interrupts_enable, HIGH, latency_override = 2)
	tick()

	expect_tick(test_runner, tick_index, 1)
	tick()

	expect_tick(test_runner, tick_index, 2)
	tick()

	if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = "General Timing"), sep = "") }


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
	tick(times = 2)

	expect_tick(test_runner, tick_index, 1)
	gba_request_data_processing_instruction_cycle(alu, destination_is_pc, shift_specified_by_register)
	memory_respond_data_processing_instruction_cycle(alu, destination_is_pc, shift_specified_by_register)
	expect_signal(test_runner, 1, "MREQ", memory.memory_request.output, HIGH)
	expect_signal(test_runner, 1, "SEQ", memory.sequential_cycle.output, HIGH)
	expect_signal(test_runner, 1, "OPC", memory.op_code_fetch.output, HIGH)
	expect_signal(test_runner, 1, "RW", memory.read_write.output, Memory_Read_Write.READ)
	tick()

	expect_tick(test_runner, tick_index, 2)
	expect_signal(test_runner, 2, "MREQ", memory.memory_request.output, HIGH)
	expect_signal(test_runner, 2, "SEQ", memory.sequential_cycle.output, HIGH)
	expect_signal(test_runner, 2, "OPC", memory.op_code_fetch.output, HIGH)
	expect_signal(test_runner, 2, "RW", memory.read_write.output, Memory_Read_Write.READ)
	pc: = gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^
	L: u32 = gba_core.executing_thumb.output ? 2 : 4
	data_in: = memory_read_u32(pc + 2 * L)
	expect_signal(test_runner, 2, "DIN", gba_core.data_in.output, data_in)
	tick()

	if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = "Data Processing Instruction Cycle"), sep = "") }


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