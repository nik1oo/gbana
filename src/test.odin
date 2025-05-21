package gbana
import "base:runtime"
import "core:fmt"
import "core:testing"
import "core:math/rand"
import "core:os"
import "core:log"
import "core:container/queue"


PRINT_ALL_TEST_TIMELINES:: #config(PRINT_ALL_TEST_TIMELINES, false)


// UTIL //
LOW_HIGH: [2]bool = { LOW, HIGH }
expect_tick:: proc(test_runner: ^testing.T, observed_value: uint, expected_value: uint, loc: = #caller_location) {
	testing.expect(test_runner, observed_value == expected_value, msg = fmt.tprint("[tick ", expected_value, "] ", "tick_index is ", observed_value, ", but should be ", expected_value, ".", sep = ""), loc = loc) }
expect_value:: proc(test_runner: ^testing.T, tick: uint, value_name: string, observed_value: $T, expected_value: T, loc: = #caller_location) {
	testing.expect(test_runner, observed_value == expected_value, msg = fmt.tprint("[tick ", tick, "] ", value_name, " is ", observed_value, ", but should be ", expected_value, ".", sep = ""), loc = loc) }
expect_signal:: proc(test_runner: ^testing.T, tick: uint, $signal_name: string, expected_value: $T, loc: = #caller_location) {
	using state: ^State = cast(^State)context.user_ptr
	observed_value: T
	when signal_name == "MREQ" do observed_value = memory.memory_request.output
	else when signal_name == "SEQ" do observed_value = memory.sequential_cycle.output
	else when signal_name == "RW" do observed_value = memory.read_write.output
	else when signal_name == "A" do observed_value = memory.address.output
	else when signal_name == "WAIT" do observed_value = gba_core.wait.output
	else when signal_name == "DOUT" do observed_value = memory.data_out.output
	else when signal_name == "DIN" do observed_value = gba_core.data_in.output
	else when signal_name == "ABORT" do observed_value = gba_core.abort.output
	else when signal_name == "RESET" do observed_value = gba_core.reset.output
	else when signal_name == "EXEC" do observed_value = gba_core.execute_cycle.output
	else when signal_name == "OPC" do observed_value = memory.op_code_fetch.output
	else when signal_name == "MAS" do observed_value = memory.memory_access_size.output
	else do log.fatal("Unspecified signal name:", signal_name, location = loc)
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
	signal_put(&signal, LOW, 0)
	signal_put(&signal, HIGH, 1)
	expect_value(test_runner, 0, "S", signal.output, LOW)
	signal_tick(&signal)

	expect_value(test_runner, 1, "S", signal.output, HIGH)
	signal_put(&signal, LOW, 1)
	signal_tick(&signal)

	expect_value(test_runner, 2, "S", signal.output, LOW)
	signal_put(&signal, HIGH, 2)
	signal_tick(&signal)

	expect_value(test_runner, 3, "S", signal.output, LOW)
	signal_tick(&signal)

	expect_value(test_runner, 4, "S", signal.output, HIGH)
	signal_put(&signal, LOW, 2)
	signal_put(&signal, HIGH, 4)
	signal_tick(&signal)

	expect_value(test_runner, 5, "S", signal.output, HIGH)
	signal_tick(&signal)

	expect_value(test_runner, 6, "S", signal.output, LOW)
	signal_tick(&signal)

	expect_value(test_runner, 7, "S", signal.output, LOW)
	signal_tick(&signal)

	expect_value(test_runner, 8, "S", signal.output, HIGH)
	signal_tick(&signal) }


@(test)
test_main_clock:: proc(test_runner: ^testing.T) {
	using state: State
	label:: "Main Clock"
	context = initialize_context(&state)
	allocate()

	initialize()
	tick()
	for tick(n = 8) {
		if tick_index % 2 == 1 do testing.expect(test_runner, gba_core.main_clock.output == LOW)
		if tick_index % 2 == 0 do testing.expect(test_runner, gba_core.main_clock.output == HIGH) }
	if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = label), sep = "") }


@(test)
test_memory_sequence:: proc(test_runner: ^testing.T) {
	using state: State
	label:: "Memory Sequence"
	context = initialize_context(&state)
	allocate()
	addresses: = generate_random_addresses()
	data_out: = rand.uint32()

	for read_write in Memory_Read_Write do for address in addresses {
		initialize()
		tick(times = 4)

		expect_tick(test_runner, tick_index, 3)
		gba_request_memory_sequence(sequential_cycle = LOW, read_write = read_write, address = address, data_out = data_out)
		expect_signal(test_runner, 3, "MREQ", HIGH)
		expect_signal(test_runner, 3, "SEQ", LOW)
		tick()

		expect_tick(test_runner, tick_index, 4)
		expect_signal(test_runner, 4, "MREQ", HIGH)
		expect_signal(test_runner, 4, "SEQ", LOW)
		expect_signal(test_runner, 4, "RW", read_write)
		tick()

		expect_tick(test_runner, tick_index, 5)
		memory_respond_memory_sequence(sequential_cycle = LOW, read_write = read_write, address = address)
		expect_signal(test_runner, 5, "RW", read_write)
		expect_signal(test_runner, 5, "A", address)
		if read_write == .WRITE do expect_signal(test_runner, 5, "DOUT", data_out)
		expect_signal(test_runner, 5, "WAIT", LOW)
		tick()

		expect_tick(test_runner, tick_index, 6)
		expect_signal(test_runner, 6, "A", address)
		if read_write == .WRITE do expect_signal(test_runner, 6, "DOUT", data_out)
		else do expect_signal(test_runner, 6, "DIN", memory_read_u32(address))
		if address == addresses[0] do expect_signal(test_runner, 6, "ABORT", LOW)
		else do expect_signal(test_runner, 6, "ABORT", HIGH)
		tick()

		expect_tick(test_runner, tick_index, 7)
		if read_write == .WRITE do expect_signal(test_runner, 7, "DOUT", data_out)
		tick()

		if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = label), sep = "") } }


@(test)
test_N_cycle:: proc(test_runner: ^testing.T) {
	using state: State
	label:: "N-Cycle"
	context = initialize_context(&state)
	allocate()
	addresses: = generate_random_addresses()
	data_out: = rand.uint32()

	for read_write in Memory_Read_Write do for address in addresses {
		initialize()
		tick(times = 4)

		expect_tick(test_runner, tick_index, 3)
		gba_request_memory_sequence(sequential_cycle = LOW, read_write = read_write, address = address, data_out = data_out)
		expect_signal(test_runner, 3, "MREQ", HIGH)
		expect_signal(test_runner, 3, "SEQ", LOW)
		tick()

		expect_tick(test_runner, tick_index, 4)
		expect_signal(test_runner, 4, "MREQ", HIGH)
		expect_signal(test_runner, 4, "SEQ", LOW)
		expect_signal(test_runner, 4, "RW", read_write)
		tick()

		expect_tick(test_runner, tick_index, 5)
		memory_respond_N_cycle(read_write = read_write, address = address)
		expect_signal(test_runner, 5, "RW", read_write)
		expect_signal(test_runner, 5, "A", address)
		if read_write == .WRITE do expect_signal(test_runner, 5, "DOUT", data_out)
		expect_signal(test_runner, 5, "WAIT", LOW)
		tick()

		expect_tick(test_runner, tick_index, 6)
		expect_signal(test_runner, 6, "A", address)
		if read_write == .WRITE do expect_signal(test_runner, 6, "DOUT", data_out)
		else do expect_signal(test_runner, 6, "DIN", memory_read_u32(address))
		if address == addresses[0] do expect_signal(test_runner, 6, "ABORT", LOW)
		else do expect_signal(test_runner, 6, "ABORT", HIGH)
		tick()

		expect_tick(test_runner, tick_index, 7)
		if read_write == .WRITE do expect_signal(test_runner, 7, "DOUT", data_out)
		tick()

		if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = label), sep = "") } }


@(test)
test_S_cycle:: proc(test_runner: ^testing.T) {
	using state: State
	label:: "S-Cycle"
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
		expect_signal(test_runner, 3, "MREQ", HIGH)
		expect_signal(test_runner, 3, "SEQ", LOW)
		tick()

		expect_tick(test_runner, tick_index, 4)
		expect_signal(test_runner, 4, "MREQ", HIGH)
		expect_signal(test_runner, 4, "SEQ", LOW)
		tick()

		expect_tick(test_runner, tick_index, 5)
		gba_request_memory_sequence(sequential_cycle = HIGH, read_write = read_write, address = address + 0, data_out = data_out)
		memory_respond_N_cycle(read_write = read_write, address = address)
		expect_signal(test_runner, 5, "MREQ", HIGH)
		expect_signal(test_runner, 5, "SEQ", HIGH)
		expect_signal(test_runner, 5, "A", address)
		if read_write == .WRITE do expect_signal(test_runner, 5, "DOUT", data_out)
		tick()

		expect_tick(test_runner, tick_index, 6)
		expect_signal(test_runner, 6, "MREQ", HIGH)
		expect_signal(test_runner, 6, "SEQ", HIGH)
		expect_signal(test_runner, 6, "A", address)
		if read_write == .WRITE do expect_signal(test_runner, 6, "DOUT", data_out)
		else do expect_signal(test_runner, 6, "DIN", memory_read_u32(address))
		tick()

		expect_tick(test_runner, tick_index, 7)
		gba_request_memory_sequence(sequential_cycle = HIGH, read_write = read_write, address = address + 4, data_out = data_out)
		memory_respond_S_cycle(read_write = read_write, address = address)
		expect_signal(test_runner, 7, "MREQ", HIGH)
		expect_signal(test_runner, 7, "SEQ", HIGH)
		expect_signal(test_runner, 7, "A", address)
		if read_write == .WRITE do expect_signal(test_runner, 7, "DOUT", data_out)
		tick()

		expect_tick(test_runner, tick_index, 8)
		expect_signal(test_runner, 8, "MREQ", HIGH)
		expect_signal(test_runner, 8, "SEQ", HIGH)
		expect_signal(test_runner, 8, "A", address)
		if read_write == .WRITE do expect_signal(test_runner, 8, "DOUT", data_out)
		else do expect_signal(test_runner, 8, "DIN", memory_read_u32(address))
		tick()

		expect_tick(test_runner, tick_index, 9)
		memory_respond_S_cycle(read_write = read_write, address = address)
		tick()

		if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = label), sep = "") } }


@(test)
test_I_cycle:: proc(test_runner: ^testing.T) {
	using state: State
	label:: "I-Cycle"
	context = initialize_context(&state)
	allocate()

	initialize()
	tick(times = 2)

	expect_tick(test_runner, tick_index, 1)
	gba_initiate_I_cycle()
	expect_signal(test_runner, 1, "MREQ", LOW)
	expect_signal(test_runner, 1, "SEQ", LOW)
	tick()

	expect_tick(test_runner, tick_index, 2)
	expect_signal(test_runner, 2, "MREQ", LOW)
	expect_signal(test_runner, 2, "SEQ", LOW)
	tick()

	if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = label), sep = "") }


@(test)
test_MIS_cycle:: proc(test_runner: ^testing.T) {
	using state: State
	label:: "MIS-Cycle"
	context = initialize_context(&state)
	allocate()
	addresses: = generate_random_addresses()
	address: = addresses[0]
	data_out: = rand.uint32()
	read_write: = Memory_Read_Write.READ

	initialize()
	tick(times = 4)

	expect_tick(test_runner, tick_index, 3)
	gba_request_MIS_cycle(read_write = read_write, address = address, data_out = data_out)
	expect_signal(test_runner, 3, "MREQ", LOW)
	expect_signal(test_runner, 3, "SEQ", LOW)
	tick()

	expect_tick(test_runner, tick_index, 4)
	expect_signal(test_runner, 4, "MREQ", LOW)
	expect_signal(test_runner, 4, "SEQ", LOW)
	tick()

	expect_tick(test_runner, tick_index, 5)
	memory_respond_MIS_cycle(read_write = read_write, address = address)
	expect_signal(test_runner, 5, "MREQ", HIGH)
	expect_signal(test_runner, 5, "SEQ", HIGH)
	expect_signal(test_runner, 5, "A", address)
	if read_write == .WRITE do expect_signal(test_runner, 5, "DOUT", data_out)
	tick()

	expect_tick(test_runner, tick_index, 6)
	expect_signal(test_runner, 6, "MREQ", HIGH)
	expect_signal(test_runner, 6, "SEQ", HIGH)
	expect_signal(test_runner, 6, "A", address)
	if read_write == .WRITE do expect_signal(test_runner, 6, "DOUT", data_out)
	else do expect_signal(test_runner, 6, "DIN", memory_read_u32(address))
	tick()

	if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = label), sep = "") }


@(test)
test_depipelined_addressing:: proc(test_runner: ^testing.T) {
	using state: State
	label:: "Depipelined Addressing"
	context = initialize_context(&state)
	allocate()
	addresses: = generate_random_addresses()
	address: = addresses[0]

	initialize()
	tick(times = 4)

	expect_tick(test_runner, tick_index, 3)
	signal_put(&memory.memory_request, HIGH, 0)
	signal_put(&memory.sequential_cycle, LOW, 0)
	tick()

	expect_tick(test_runner, tick_index, 4)
	expect_signal(test_runner, 4, "MREQ", HIGH)
	expect_signal(test_runner, 4, "SEQ", LOW)
	tick()

	expect_tick(test_runner, tick_index, 5)
	expect_signal(test_runner, 5, "MREQ", HIGH)
	expect_signal(test_runner, 5, "SEQ", LOW)
	signal_put(&memory.address, address, 0)
	tick()

	expect_tick(test_runner, tick_index, 6)
	expect_signal(test_runner, 6, "A", address)
	tick()

	expect_tick(test_runner, tick_index, 7)
	expect_signal(test_runner, 7, "A", address)

	if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = label), sep = "") }


@(test)
test_DW_cycle:: proc(test_runner: ^testing.T) {
	using state: State
	label:: "DW-Cycle"
	context = initialize_context(&state)
	allocate()
	addresses: = generate_random_addresses()
	data_out: = rand.uint32()

	for address in addresses {
		initialize()
		tick(times = 4)

		expect_tick(test_runner, tick_index, 3)
		gba_request_DW_cycle(sequential_cycle = LOW, address = address, data_out = data_out)
		expect_signal(test_runner, 3, "MREQ", HIGH)
		expect_signal(test_runner, 3, "SEQ", LOW)
		tick()

		expect_tick(test_runner, tick_index, 4)
		expect_signal(test_runner, 4, "MREQ", HIGH)
		expect_signal(test_runner, 4, "SEQ", LOW)
		expect_signal(test_runner, 4, "RW", Memory_Read_Write.WRITE)
		tick()

		expect_tick(test_runner, tick_index, 5)
		memory_respond_DW_cycle(sequential_cycle = LOW, address = address)
		expect_signal(test_runner, 5, "RW", Memory_Read_Write.WRITE)
		expect_signal(test_runner, 5, "A", address)
		expect_signal(test_runner, 5, "DOUT", data_out)
		expect_signal(test_runner, 5, "WAIT", LOW)
		tick()

		expect_tick(test_runner, tick_index, 6)
		expect_signal(test_runner, 6, "A", address)
		expect_signal(test_runner, 6, "DOUT", data_out)
		if address == addresses[0] do expect_signal(test_runner, 6, "ABORT", LOW)
		else do expect_signal(test_runner, 6, "ABORT", HIGH)
		tick()

		expect_tick(test_runner, tick_index, 7)
		expect_signal(test_runner, 7, "DOUT", data_out)
		tick()

		if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = label), sep = "") } }


@(test)
test_DR_cycle:: proc(test_runner: ^testing.T) {
	using state: State
	label:: "DR-Cycle"
	context = initialize_context(&state)
	allocate()
	addresses: = generate_random_addresses()

	for address in addresses {
		initialize()
		tick(times = 4)

		expect_tick(test_runner, tick_index, 3)
		gba_request_DR_cycle(sequential_cycle = LOW, address = address)
		expect_signal(test_runner, 3, "MREQ", HIGH)
		expect_signal(test_runner, 3, "SEQ", LOW)
		tick()

		expect_tick(test_runner, tick_index, 4)
		expect_signal(test_runner, 4, "MREQ", HIGH)
		expect_signal(test_runner, 4, "SEQ", LOW)
		expect_signal(test_runner, 4, "RW", Memory_Read_Write.READ)
		tick()

		expect_tick(test_runner, tick_index, 5)
		memory_respond_DR_cycle(sequential_cycle = LOW, address = address)
		expect_signal(test_runner, 5, "RW", Memory_Read_Write.READ)
		expect_signal(test_runner, 5, "A", address)
		expect_signal(test_runner, 5, "WAIT", LOW)
		tick()

		expect_tick(test_runner, tick_index, 6)
		expect_signal(test_runner, 6, "A", address)
		expect_signal(test_runner, 6, "DIN", memory_read_u32(address))
		if address == addresses[0] do expect_signal(test_runner, 6, "ABORT", LOW)
		else do expect_signal(test_runner, 6, "ABORT", HIGH)
		tick()

		if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = label), sep = "") } }


@(test)
test_delayed_memory_sequence:: proc(test_runner: ^testing.T) {
	using state: State
	label:: "Delayed Memory Sequence"
	context = initialize_context(&state)
	allocate()
	address: = generate_random_EWRAM_address()
	data_out: = rand.uint32()

	for read_write in Memory_Read_Write {
		initialize()
		tick(times = 4)

		expect_tick(test_runner, tick_index, 3)
		gba_request_memory_sequence(sequential_cycle = LOW, read_write = read_write, address = address, data_out = data_out, memory_access_size = .HALFWORD)
		expect_signal(test_runner, 3, "MREQ", HIGH)
		expect_signal(test_runner, 3, "SEQ", LOW)
		tick()

		expect_tick(test_runner, tick_index, 4)
		expect_signal(test_runner, 4, "MREQ", HIGH)
		expect_signal(test_runner, 4, "SEQ", LOW)
		expect_signal(test_runner, 4, "RW", read_write)
		tick()

		memory_respond_memory_sequence(sequential_cycle = LOW, read_write = read_write, address = address, memory_access_size = .HALFWORD)
		wait_cycles: uint = uint(memory_bus_latency_from_address(address, 4)) - 1
		for i in 0 ..< wait_cycles {
			expect_signal(test_runner, 5 + 2 * i, "WAIT", HIGH)
			tick()

			expect_signal(test_runner, 5 + 2 * i + 1, "WAIT", HIGH)
			tick() }

		expect_tick(test_runner, tick_index, 5 + 2 * wait_cycles)
		expect_signal(test_runner, 5 + 2 * wait_cycles, "RW", read_write)
		expect_signal(test_runner, 5 + 2 * wait_cycles, "A", address)
		if read_write == .WRITE do expect_signal(test_runner, 5 + 2 * wait_cycles, "DOUT", data_out)
		expect_signal(test_runner, 5 + 2 * wait_cycles, "WAIT", LOW)
		tick()

		expect_tick(test_runner, tick_index, 6 + 2 * wait_cycles)
		expect_signal(test_runner, 6 + 2 * wait_cycles, "A", address)
		if read_write == .WRITE do expect_signal(test_runner, 6 + 2 * wait_cycles, "DOUT", data_out)
		else do expect_signal(test_runner, 6 + 2 * wait_cycles, "DIN", memory_read_u32(address))
		tick()

		expect_tick(test_runner, tick_index, 7 + 2 * wait_cycles)
		if read_write == .WRITE do expect_signal(test_runner, 7 + 2 * wait_cycles, "DOUT", data_out)
		tick()

		if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = label), sep = "") } }


@(test)
test_halfword_memory_sequence:: proc(test_runner: ^testing.T) {
	using state: State
	label:: "Halfword Memory Sequence"
	context = initialize_context(&state)
	allocate()
	address: = generate_random_VRAM_address()
	data_out: = rand.uint32()

	for read_write in Memory_Read_Write {
		initialize()
		tick(times = 4)

		expect_tick(test_runner, tick_index, 3)
		gba_request_memory_sequence(sequential_cycle = LOW, read_write = read_write, address = address, data_out = data_out)
		expect_signal(test_runner, 3, "MREQ", HIGH)
		expect_signal(test_runner, 3, "SEQ", LOW)
		tick()

		expect_tick(test_runner, tick_index, 4)
		expect_signal(test_runner, 4, "MREQ", HIGH)
		expect_signal(test_runner, 4, "SEQ", LOW)
		expect_signal(test_runner, 4, "RW", read_write)
		tick()

		expect_tick(test_runner, tick_index, 5)
		memory_respond_memory_sequence(sequential_cycle = LOW, read_write = read_write, address = address)
		// VRAM has a 16-bit-wide bus and an access latency of 2 cycles for word-sized requests. //
		for i in 0 ..< 4 {
			expect_signal(test_runner, 5 + uint(i), "WAIT", HIGH)
			tick() }

		expect_signal(test_runner, 9, "WAIT", LOW)
		expect_signal(test_runner, 9, "RW", read_write)
		expect_signal(test_runner, 9, "A", address)
		if read_write == .WRITE do expect_signal(test_runner, 9, "DOUT", data_out)
		expect_signal(test_runner, 9, "WAIT", LOW)
		tick()

		expect_tick(test_runner, tick_index, 10)
		expect_signal(test_runner, 10, "A", address)
		if read_write == .WRITE do expect_signal(test_runner, 10, "DOUT", data_out)
		else do expect_signal(test_runner, 10, "DIN", memory_read_u32(address))
		tick()

		expect_tick(test_runner, tick_index, 11)
		if read_write == .WRITE do expect_signal(test_runner, 11, "DOUT", data_out)
		expect_signal(test_runner, 11, "ABORT", LOW)
		tick()

		if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = label), sep = "") } }


@(test)
test_byte_memory_sequence:: proc(test_runner: ^testing.T) {
	/* Byte-wide-bus memory exists only on cartridges with SRAM memory. GBANA emulates a cartridge with Flash memory. */ }


@(test)
test_RS_cycle:: proc(test_runner: ^testing.T) {
	using state: State
	label:: "RS-Cycle"
	context = initialize_context(&state)
	allocate()
	initialize()
	tick(times = 2)

	gba_request_RS_cycle()
	memory_respond_RS_cycle()

	for i in uint(1) ..= uint(2) {
		expect_tick(test_runner, tick_index, i)
		expect_signal(test_runner, i, "RESET", HIGH)
		expect_signal(test_runner, i, "MREQ", LOW)
		expect_signal(test_runner, i, "SEQ", LOW)
		expect_signal(test_runner, i, "EXEC", LOW)
		tick() }

	for i in uint(3) ..= uint(6) {
		expect_tick(test_runner, tick_index, i)
		expect_signal(test_runner, i, "RESET", LOW)
		expect_signal(test_runner, i, "MREQ", LOW)
		expect_signal(test_runner, i, "SEQ", LOW)
		expect_signal(test_runner, i, "EXEC", LOW)
		tick() }

	for i in uint(7) ..= uint(8) {
		expect_tick(test_runner, tick_index, i)
		expect_signal(test_runner, i, "RESET", LOW)
		expect_signal(test_runner, i, "MREQ", HIGH)
		expect_signal(test_runner, i, "SEQ", LOW)
		expect_signal(test_runner, i, "EXEC", HIGH)
		tick() }

	for i in uint(9) ..= uint(10) {
		expect_tick(test_runner, tick_index, i)
		expect_signal(test_runner, i, "RESET", LOW)
		expect_signal(test_runner, i, "MREQ", HIGH)
		expect_signal(test_runner, i, "SEQ", HIGH)
		expect_signal(test_runner, i, "EXEC", HIGH)
		if tick_index % 2 == 0 do expect_signal(test_runner, 10, "DIN", memory_read_u32(0))
		tick() }

	if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = label), sep = "") }


@(test)
test_general_timing:: proc(test_runner: ^testing.T) {
	using state: State
	label:: "General Timing"
	context = initialize_context(&state)
	allocate()
	initialize()
	tick()

	expect_tick(test_runner, tick_index, 0)
	signal_put(&memory.memory_request, HIGH, 1)
	signal_put(&memory.sequential_cycle, HIGH, 1)
	signal_put(&gba_core.execute_cycle, HIGH, 1)
	signal_put(&memory.address, 0b0, 1)
	signal_put(&gba_core.big_endian, HIGH, 1)
	signal_put(&gba_core.synchronous_interrupts_enable, HIGH, 1)
	signal_put(&memory.read_write, Memory_Read_Write.READ, 2)
	signal_put(&memory.memory_access_size, Memory_Access_Size.WORD, 2)
	signal_put(&memory.lock, HIGH, 2)
	signal_put(&gba_core.processor_mode, GBA_Processor_Mode.System, 2)
	signal_put(&gba_core.executing_thumb, HIGH, 2)
	signal_put(&memory.op_code_fetch, HIGH, 2)
	signal_put(&gba_core.synchronous_interrupts_enable, HIGH, 2)
	tick()

	expect_tick(test_runner, tick_index, 1)
	tick()

	expect_tick(test_runner, tick_index, 2)
	tick()

	if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = label), sep = "") }


@(test)
test_address_bus_control:: proc(test_runner: ^testing.T) {
	using state: State
	label:: "Address Bus Control"
	context = initialize_context(&state)
	allocate()
	initialize()
	tick(times = 2)

	expect_tick(test_runner, tick_index, 1)
	memory_initiate_address_bus_control(LOW)
	expect_value(test_runner, 1, "A.enabled", memory.address.enabled, LOW)
	expect_value(test_runner, 1, "RW.enabled", memory.read_write.enabled, LOW)
	expect_value(test_runner, 1, "LOCK.enabled", memory.lock.enabled, LOW)
	expect_value(test_runner, 1, "OPC.enabled", memory.op_code_fetch.enabled, LOW)
	expect_value(test_runner, 1, "MAS.enabled", memory.memory_access_size.enabled, LOW)
	tick(times = 2)

	expect_tick(test_runner, tick_index, 3)
	memory_initiate_address_bus_control(LOW)
	expect_value(test_runner, 3, "A.enabled", memory.address.enabled, LOW)
	expect_value(test_runner, 3, "RW.enabled", memory.read_write.enabled, LOW)
	expect_value(test_runner, 3, "LOCK.enabled", memory.lock.enabled, LOW)
	expect_value(test_runner, 3, "OPC.enabled", memory.op_code_fetch.enabled, LOW)
	expect_value(test_runner, 3, "MAS.enabled", memory.memory_access_size.enabled, LOW)

	if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = label), sep = "") }


@(test)
test_data_bus_control:: proc(test_runner: ^testing.T) {
	using state: State
	label:: "Data Bus Control"
	context = initialize_context(&state)
	allocate()
	initialize()
	tick(times = 2)

	expect_tick(test_runner, tick_index, 1)
	memory_initiate_data_bus_control(LOW)
	expect_value(test_runner, 1, "DIN.enabled", gba_core.data_in.enabled, LOW)
	expect_value(test_runner, 1, "DOUT.enabled", memory.data_out.enabled, LOW)
	tick(times = 2)

	expect_tick(test_runner, tick_index, 3)
	memory_initiate_data_bus_control(LOW)
	expect_value(test_runner, 3, "DIN.enabled", gba_core.data_in.enabled, LOW)
	expect_value(test_runner, 3, "DOUT.enabled", memory.data_out.enabled, LOW)

	if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = label), sep = "") }


@(test)
test_expection_control:: proc(test_runner: ^testing.T) {
	using state: State
	label:: "Exception Control"
	context = initialize_context(&state)
	allocate()
	initialize()
	tick()

	expect_tick(test_runner, tick_index, 0)
	signal_put(&gba_core.abort, HIGH, 1)
	signal_put(&gba_core.reset, HIGH, 1)
	signal_put(&gba_core.fast_interrupt_request, HIGH, 2)
	signal_put(&gba_core.interrupt_request, HIGH, 2)
	signal_put(&gba_core.abort, LOW, 2)
	tick()

	expect_tick(test_runner, tick_index, 1)
	tick()

	expect_tick(test_runner, tick_index, 2)
	tick()

	if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = label), sep = "") }


@(test)
test_address_pipeline_control:: proc(test_runner: ^testing.T) {
	using state: State
	label:: "Address Pipeline Control"
	context = initialize_context(&state)
	allocate()
	initialize()
	tick()

	expect_tick(test_runner, tick_index, 0)
	signal_put(&memory.address, 0b0, 1)
	signal_put(&memory.read_write, Memory_Read_Write.READ, 1)
	signal_put(&memory.lock, true, 1)
	signal_put(&memory.op_code_fetch, true, 1)
	signal_put(&memory.memory_access_size, Memory_Access_Size.HALFWORD, 1)
	tick()

	expect_tick(test_runner, tick_index, 1)
	tick()

	expect_tick(test_runner, tick_index, 2)
	tick()

	if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = label), sep = "") }


@(test)
test_BABLI_cycle:: proc(test_runner: ^testing.T) {
	using state: State
	label:: "BABLI-Cycle"
	context = initialize_context(&state)
	allocate()
	alu: u32 = rand.uint32()
	initialize()
	tick(times = 2)

	expect_tick(test_runner, tick_index, 1)
	gba_request_BABLI_cycle(alu)
	memory_respond_BABLI_cycle(alu)
	expect_signal(test_runner, 1, "MREQ", HIGH)
	expect_signal(test_runner, 1, "SEQ", LOW)
	expect_signal(test_runner, 1, "OPC", HIGH)
	expect_signal(test_runner, 1, "RW", Memory_Read_Write.READ)
	pc: = gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^
	L: u32 = gba_core.executing_thumb.output ? 2 : 4
	expect_signal(test_runner, 1, "A", pc + 2 * L)
	tick()

	expect_tick(test_runner, tick_index, 2)
	expect_signal(test_runner, 2, "MREQ", HIGH)
	expect_signal(test_runner, 2, "SEQ", LOW)
	expect_signal(test_runner, 2, "OPC", HIGH)
	expect_signal(test_runner, 2, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 2, "A", pc + 2 * L)
	expect_signal(test_runner, 2, "DIN", memory_read_u32(pc + 2 * L))
	tick()

	expect_tick(test_runner, tick_index, 3)
	expect_signal(test_runner, 3, "MREQ", HIGH)
	expect_signal(test_runner, 3, "SEQ", HIGH)
	expect_signal(test_runner, 3, "OPC", HIGH)
	expect_signal(test_runner, 3, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 3, "A", alu)
	tick()

	expect_tick(test_runner, tick_index, 4)
	expect_signal(test_runner, 4, "MREQ", HIGH)
	expect_signal(test_runner, 4, "SEQ", HIGH)
	expect_signal(test_runner, 4, "OPC", HIGH)
	expect_signal(test_runner, 4, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 4, "A", alu)
	expect_signal(test_runner, 4, "DIN", memory_read_u32(alu))
	tick()

	expect_tick(test_runner, tick_index, 5)
	expect_signal(test_runner, 5, "MREQ", HIGH)
	expect_signal(test_runner, 5, "SEQ", HIGH)
	expect_signal(test_runner, 5, "OPC", HIGH)
	expect_signal(test_runner, 5, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 5, "A", alu + L)
	tick()

	expect_tick(test_runner, tick_index, 6)
	expect_signal(test_runner, 6, "MREQ", HIGH)
	expect_signal(test_runner, 6, "SEQ", HIGH)
	expect_signal(test_runner, 6, "OPC", HIGH)
	expect_signal(test_runner, 6, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 6, "A", alu + L)
	expect_signal(test_runner, 6, "DIN", memory_read_u32(alu + L))
	tick()

	expect_signal(test_runner, 6, "A", alu + 2 * L)

	if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = label), sep = "") }


@(test)
test_TBLI_cycle:: proc(test_runner: ^testing.T) {
	using state: State
	label:: "TBLI-Cycle"
	context = initialize_context(&state)
	allocate()
	alu: u32 = rand.uint32()
	initialize()
	tick(times = 2)

	expect_tick(test_runner, tick_index, 1)
	gba_request_TBLI_cycle(alu)
	memory_respond_TBLI_cycle(alu)
	expect_signal(test_runner, 1, "MREQ", HIGH)
	expect_signal(test_runner, 1, "SEQ", HIGH)
	expect_signal(test_runner, 1, "OPC", HIGH)
	expect_signal(test_runner, 1, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 1, "MAS", Memory_Access_Size.HALFWORD)
	pc: = gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^
	expect_signal(test_runner, 1, "A", pc + 4)
	tick()

	expect_tick(test_runner, tick_index, 2)
	expect_signal(test_runner, 2, "MREQ", HIGH)
	expect_signal(test_runner, 2, "SEQ", HIGH)
	expect_signal(test_runner, 2, "OPC", HIGH)
	expect_signal(test_runner, 2, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 2, "MAS", Memory_Access_Size.HALFWORD)
	expect_signal(test_runner, 2, "A", pc + 4)
	expect_signal(test_runner, 2, "DIN", memory_read(pc + 4, .HALFWORD))
	tick()

	expect_tick(test_runner, tick_index, 3)
	expect_signal(test_runner, 3, "MREQ", HIGH)
	expect_signal(test_runner, 3, "SEQ", LOW)
	expect_signal(test_runner, 3, "OPC", HIGH)
	expect_signal(test_runner, 3, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 3, "MAS", Memory_Access_Size.HALFWORD)
	expect_signal(test_runner, 3, "A", pc + 6)
	tick()

	expect_tick(test_runner, tick_index, 4)
	expect_signal(test_runner, 4, "MREQ", HIGH)
	expect_signal(test_runner, 4, "SEQ", LOW)
	expect_signal(test_runner, 4, "OPC", HIGH)
	expect_signal(test_runner, 4, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 4, "MAS", Memory_Access_Size.HALFWORD)
	expect_signal(test_runner, 4, "A", pc + 6)
	expect_signal(test_runner, 4, "DIN", memory_read(pc + 6, .HALFWORD))
	tick()

	expect_tick(test_runner, tick_index, 5)
	expect_signal(test_runner, 5, "MREQ", HIGH)
	expect_signal(test_runner, 5, "SEQ", HIGH)
	expect_signal(test_runner, 5, "OPC", HIGH)
	expect_signal(test_runner, 5, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 5, "MAS", Memory_Access_Size.HALFWORD)
	expect_signal(test_runner, 5, "A", alu)
	tick()

	expect_tick(test_runner, tick_index, 6)
	expect_signal(test_runner, 6, "MREQ", HIGH)
	expect_signal(test_runner, 6, "SEQ", HIGH)
	expect_signal(test_runner, 6, "OPC", HIGH)
	expect_signal(test_runner, 6, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 6, "MAS", Memory_Access_Size.HALFWORD)
	expect_signal(test_runner, 6, "A", alu)
	expect_signal(test_runner, 6, "DIN", memory_read(alu, .HALFWORD))
	tick()

	expect_tick(test_runner, tick_index, 7)
	expect_signal(test_runner, 7, "MREQ", HIGH)
	expect_signal(test_runner, 7, "SEQ", HIGH)
	expect_signal(test_runner, 7, "OPC", HIGH)
	expect_signal(test_runner, 7, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 7, "MAS", Memory_Access_Size.HALFWORD)
	expect_signal(test_runner, 7, "A", alu + 2)
	tick()

	expect_tick(test_runner, tick_index, 8)
	expect_signal(test_runner, 8, "MREQ", HIGH)
	expect_signal(test_runner, 8, "SEQ", HIGH)
	expect_signal(test_runner, 8, "OPC", HIGH)
	expect_signal(test_runner, 8, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 8, "MAS", Memory_Access_Size.HALFWORD)
	expect_signal(test_runner, 8, "A", alu + 2)
	expect_signal(test_runner, 8, "DIN", memory_read(alu + 2, .HALFWORD))
	tick()

	expect_signal(test_runner, 9, "A", alu + 4)
	tick()

	if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = label), sep = "") }


@(test)
test_BAEI_cycle:: proc(test_runner: ^testing.T) {
	using state: State
	label:: "BAEI-Cycle"
	context = initialize_context(&state)
	allocate()
	alu: u32 = rand.uint32()
	initialize()
	tick(times = 2)

	expect_tick(test_runner, tick_index, 1)
	gba_request_BAEI_cycle(alu)
	memory_respond_BAEI_cycle(alu)
	expect_signal(test_runner, 1, "MREQ", HIGH)
	expect_signal(test_runner, 1, "SEQ", LOW)
	expect_signal(test_runner, 1, "OPC", HIGH)
	expect_signal(test_runner, 1, "RW", Memory_Read_Write.READ)
	T: = gba_core.executing_thumb.output
	pc: = gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^
	W: u32 = T ? 2 : 4
	I: Memory_Access_Size = T ? .HALFWORD : .WORD
	i: Memory_Access_Size = T ? .WORD : .HALFWORD
	expect_signal(test_runner, 1, "MAS", I)
	expect_signal(test_runner, 1, "A", pc + 2 * W)
	tick()

	expect_tick(test_runner, tick_index, 2)
	expect_signal(test_runner, 2, "MREQ", HIGH)
	expect_signal(test_runner, 2, "SEQ", LOW)
	expect_signal(test_runner, 2, "OPC", HIGH)
	expect_signal(test_runner, 2, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 2, "A", pc + 2 * W)
	expect_signal(test_runner, 2, "MAS", I)
	expect_signal(test_runner, 2, "DIN", memory_read(pc + 2 * W, I))
	tick()

	if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = label), sep = "") }


@(test)
test_DPI_cycle:: proc(test_runner: ^testing.T) {
	using state: State
	label:: "DPI-Cycle"
	context = initialize_context(&state)
	allocate()
	alu: u32 = rand.uint32()

	// normal //
	destination_is_pc: bool = LOW
	shift_specified_by_register: bool = LOW
	initialize()
	T: = gba_core.executing_thumb.output
	pc: = gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^
	L: u32 = gba_core.executing_thumb.output ? 2 : 4
	i: Memory_Access_Size = T ? .HALFWORD : .WORD
	tick(times = 2)

	expect_tick(test_runner, tick_index, 1)
	gba_request_DPI_cycle(alu, destination_is_pc, shift_specified_by_register)
	memory_respond_DPI_cycle(alu, destination_is_pc, shift_specified_by_register)
	expect_signal(test_runner, 1, "MREQ", HIGH)
	expect_signal(test_runner, 1, "SEQ", HIGH)
	expect_signal(test_runner, 1, "OPC", HIGH)
	expect_signal(test_runner, 1, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 1, "A", pc + 2 * L)
	expect_signal(test_runner, 1, "MAS", i)
	tick()

	expect_tick(test_runner, tick_index, 2)
	expect_signal(test_runner, 2, "MREQ", HIGH)
	expect_signal(test_runner, 2, "SEQ", HIGH)
	expect_signal(test_runner, 2, "OPC", HIGH)
	expect_signal(test_runner, 2, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 2, "A", pc + 2 * L)
	expect_signal(test_runner, 2, "MAS", i)
	expect_signal(test_runner, 2, "DIN", memory_read_u32(pc + 2 * L))
	tick()

	// dest=pc //
	destination_is_pc = HIGH
	shift_specified_by_register = LOW
	initialize()
	tick(times = 2)

	expect_tick(test_runner, tick_index, 1)
	gba_request_DPI_cycle(alu, destination_is_pc, shift_specified_by_register)
	memory_respond_DPI_cycle(alu, destination_is_pc, shift_specified_by_register)
	expect_signal(test_runner, 1, "MREQ", HIGH)
	expect_signal(test_runner, 1, "SEQ", LOW)
	expect_signal(test_runner, 1, "OPC", HIGH)
	expect_signal(test_runner, 1, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 1, "A", pc + 2 * L)
	expect_signal(test_runner, 1, "MAS", i)
	tick()

	expect_tick(test_runner, tick_index, 2)
	// expect_signals_unchanged(test_runner, 2, "MREQ" "SEQ", "OPC", "RW", "A", "MAS", "DIN")
	expect_signal(test_runner, 2, "MREQ", HIGH)
	expect_signal(test_runner, 2, "SEQ", LOW)
	expect_signal(test_runner, 2, "OPC", HIGH)
	expect_signal(test_runner, 2, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 2, "A", pc + 2 * L)
	expect_signal(test_runner, 2, "MAS", i)
	expect_signal(test_runner, 2, "DIN", memory_read_u32(pc + 2 * L))
	tick()

	expect_tick(test_runner, tick_index, 3)
	expect_signal(test_runner, 3, "MREQ", HIGH)
	expect_signal(test_runner, 3, "SEQ", HIGH)
	expect_signal(test_runner, 3, "OPC", HIGH)
	expect_signal(test_runner, 3, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 3, "A", alu)
	expect_signal(test_runner, 3, "MAS", i)
	tick()

	expect_tick(test_runner, tick_index, 4)
	expect_signal(test_runner, 4, "MREQ", HIGH)
	expect_signal(test_runner, 4, "SEQ", HIGH)
	expect_signal(test_runner, 4, "OPC", HIGH)
	expect_signal(test_runner, 4, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 4, "A", alu)
	expect_signal(test_runner, 4, "MAS", i)
	expect_signal(test_runner, 4, "DIN", memory_read_u32(alu))
	tick()

	expect_tick(test_runner, tick_index, 5)
	expect_signal(test_runner, 5, "MREQ", HIGH)
	expect_signal(test_runner, 5, "SEQ", HIGH)
	expect_signal(test_runner, 5, "OPC", HIGH)
	expect_signal(test_runner, 5, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 5, "A", alu + L)
	expect_signal(test_runner, 5, "MAS", i)
	tick()

	expect_tick(test_runner, tick_index, 6)
	expect_signal(test_runner, 6, "MREQ", HIGH)
	expect_signal(test_runner, 6, "SEQ", HIGH)
	expect_signal(test_runner, 6, "OPC", HIGH)
	expect_signal(test_runner, 6, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 6, "A", alu + L)
	expect_signal(test_runner, 6, "MAS", i)
	expect_signal(test_runner, 6, "DIN", memory_read_u32(alu + L))
	tick()

	expect_tick(test_runner, tick_index, 7)
	expect_signal(test_runner, 7, "A", alu + 2 * L)
	tick()

	expect_tick(test_runner, tick_index, 8)
	expect_signal(test_runner, 8, "A", alu + 2 * L)
	tick()

	// shift(RS) //
	destination_is_pc = LOW
	shift_specified_by_register = HIGH
	initialize()
	tick(times = 2)

	expect_tick(test_runner, tick_index, 1)
	gba_request_DPI_cycle(alu, destination_is_pc, shift_specified_by_register)
	memory_respond_DPI_cycle(alu, destination_is_pc, shift_specified_by_register)
	expect_signal(test_runner, 1, "MREQ", LOW)
	expect_signal(test_runner, 1, "SEQ", LOW)
	expect_signal(test_runner, 1, "OPC", HIGH)
	expect_signal(test_runner, 1, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 1, "A", pc + 2 * L)
	expect_signal(test_runner, 1, "MAS", i)
	tick()

	expect_tick(test_runner, tick_index, 2)
	expect_signal(test_runner, 2, "MREQ", LOW)
	expect_signal(test_runner, 2, "SEQ", LOW)
	expect_signal(test_runner, 2, "OPC", HIGH)
	expect_signal(test_runner, 2, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 2, "A", pc + 2 * L)
	expect_signal(test_runner, 2, "MAS", i)
	expect_signal(test_runner, 6, "DIN", memory_read(pc + 2 * L, i))
	tick()

	expect_tick(test_runner, tick_index, 3)
	expect_signal(test_runner, 3, "MREQ", HIGH)
	expect_signal(test_runner, 3, "SEQ", HIGH)
	expect_signal(test_runner, 3, "OPC", LOW)
	expect_signal(test_runner, 3, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 3, "A", pc + 3 * L)
	expect_signal(test_runner, 3, "MAS", i)
	tick()

	expect_tick(test_runner, tick_index, 4)
	expect_signal(test_runner, 4, "MREQ", HIGH)
	expect_signal(test_runner, 4, "SEQ", HIGH)
	expect_signal(test_runner, 4, "OPC", LOW)
	expect_signal(test_runner, 4, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 4, "A", pc + 3 * L)
	expect_signal(test_runner, 4, "MAS", i)
	tick()

	expect_signal(test_runner, 5, "A", pc + 3 * L)
	tick()

	expect_signal(test_runner, 6, "A", pc + 3 * L)
	tick()

	// shift(RS) dest=pc //
	destination_is_pc = HIGH
	shift_specified_by_register = HIGH
	initialize()
	tick(times = 2)

	expect_tick(test_runner, tick_index, 1)
	gba_request_DPI_cycle(alu, destination_is_pc, shift_specified_by_register)
	memory_respond_DPI_cycle(alu, destination_is_pc, shift_specified_by_register)
	expect_signal(test_runner, 1, "MREQ", LOW)
	expect_signal(test_runner, 1, "SEQ", LOW)
	expect_signal(test_runner, 1, "OPC", HIGH)
	expect_signal(test_runner, 1, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 1, "A", pc + 8)
	expect_signal(test_runner, 1, "MAS", Memory_Access_Size.WORD)
	tick()

	expect_tick(test_runner, tick_index, 2)
	expect_signal(test_runner, 2, "MREQ", LOW)
	expect_signal(test_runner, 2, "SEQ", LOW)
	expect_signal(test_runner, 2, "OPC", HIGH)
	expect_signal(test_runner, 2, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 2, "A", pc + 8)
	expect_signal(test_runner, 2, "MAS", Memory_Access_Size.WORD)
	expect_signal(test_runner, 2, "DIN", memory_read_u32(pc + 8))
	tick()

	expect_tick(test_runner, tick_index, 3)
	expect_signal(test_runner, 3, "MREQ", HIGH)
	expect_signal(test_runner, 3, "SEQ", LOW)
	expect_signal(test_runner, 3, "OPC", LOW)
	expect_signal(test_runner, 3, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 3, "A", pc + 12)
	expect_signal(test_runner, 3, "MAS", Memory_Access_Size.WORD)
	tick()

	expect_tick(test_runner, tick_index, 4)
	expect_signal(test_runner, 4, "MREQ", HIGH)
	expect_signal(test_runner, 4, "SEQ", LOW)
	expect_signal(test_runner, 4, "OPC", LOW)
	expect_signal(test_runner, 4, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 4, "A", pc + 12)
	expect_signal(test_runner, 4, "MAS", Memory_Access_Size.WORD)
	tick()

	expect_tick(test_runner, tick_index, 5)
	expect_signal(test_runner, 5, "MREQ", HIGH)
	expect_signal(test_runner, 5, "SEQ", HIGH)
	expect_signal(test_runner, 5, "OPC", HIGH)
	expect_signal(test_runner, 5, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 5, "A", alu)
	expect_signal(test_runner, 5, "MAS", Memory_Access_Size.WORD)
	tick()

	expect_tick(test_runner, tick_index, 6)
	expect_signal(test_runner, 6, "MREQ", HIGH)
	expect_signal(test_runner, 6, "SEQ", HIGH)
	expect_signal(test_runner, 6, "OPC", HIGH)
	expect_signal(test_runner, 6, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 6, "A", alu)
	expect_signal(test_runner, 6, "MAS", Memory_Access_Size.WORD)
	expect_signal(test_runner, 6, "DIN", memory_read_u32(alu))
	tick()

	expect_tick(test_runner, tick_index, 7)
	expect_signal(test_runner, 7, "MREQ", HIGH)
	expect_signal(test_runner, 7, "SEQ", HIGH)
	expect_signal(test_runner, 7, "OPC", HIGH)
	expect_signal(test_runner, 7, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 7, "A", alu + 4)
	expect_signal(test_runner, 7, "MAS", Memory_Access_Size.WORD)
	tick()

	expect_tick(test_runner, tick_index, 8)
	expect_signal(test_runner, 8, "MREQ", HIGH)
	expect_signal(test_runner, 8, "SEQ", HIGH)
	expect_signal(test_runner, 8, "OPC", HIGH)
	expect_signal(test_runner, 8, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 8, "A", alu + 4)
	expect_signal(test_runner, 8, "MAS", Memory_Access_Size.WORD)
	expect_signal(test_runner, 8, "DIN", memory_read_u32(alu + 4))
	tick()

	expect_signal(test_runner, 9, "A", alu + 8)
	tick()

	expect_signal(test_runner, 10, "A", alu + 8)
	tick()

	if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = label), sep = "") }


@(test)
test_MAMAI_cycle:: proc(test_runner: ^testing.T) {
	using state: State
	label:: "MAMAI-Cycle"
	context = initialize_context(&state)
	allocate()
	alu: u32 = rand.uint32()

	// Multiply //
	accumulate, long: bool = LOW, LOW
	initialize()
	T: = gba_core.executing_thumb.output
	pc: = gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^
	L: u32 = gba_core.executing_thumb.output ? 2 : 4
	i: Memory_Access_Size = T ? .HALFWORD : .WORD
	tick(times = 2)

	expect_tick(test_runner, tick_index, 1)
	gba_request_MAMAI_cycle(accumulate, long)
	memory_respond_MAMAI_cycle(accumulate, long)
	expect_signal(test_runner, 1, "MREQ", LOW)
	expect_signal(test_runner, 1, "SEQ", LOW)
	expect_signal(test_runner, 1, "OPC", HIGH)
	expect_signal(test_runner, 1, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 1, "A", pc + 2 * L)
	expect_signal(test_runner, 1, "MAS", i)
	tick()

	expect_tick(test_runner, tick_index, 2)
	expect_signal(test_runner, 2, "MREQ", LOW)
	expect_signal(test_runner, 2, "SEQ", LOW)
	expect_signal(test_runner, 2, "OPC", HIGH)
	expect_signal(test_runner, 2, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 2, "A", pc + 2 * L)
	expect_signal(test_runner, 2, "MAS", i)
	expect_signal(test_runner, 2, "DIN", memory_read_u32(pc + 2 * L))
	tick()

	expect_tick(test_runner, tick_index, 3)
	expect_signal(test_runner, 3, "MREQ", LOW)
	expect_signal(test_runner, 3, "SEQ", LOW)
	expect_signal(test_runner, 3, "OPC", LOW)
	expect_signal(test_runner, 3, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 3, "A", pc + 3 * L)
	expect_signal(test_runner, 3, "MAS", i)
	tick()

	expect_tick(test_runner, tick_index, 4)
	expect_signal(test_runner, 4, "MREQ", LOW)
	expect_signal(test_runner, 4, "SEQ", LOW)
	expect_signal(test_runner, 4, "OPC", LOW)
	expect_signal(test_runner, 4, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 4, "A", pc + 3 * L)
	expect_signal(test_runner, 4, "MAS", i)
	tick()

	expect_tick(test_runner, tick_index, 5)
	expect_signal(test_runner, 5, "MREQ", HIGH)
	expect_signal(test_runner, 5, "SEQ", HIGH)
	expect_signal(test_runner, 5, "OPC", LOW)
	expect_signal(test_runner, 5, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 5, "A", pc + 3 * L)
	expect_signal(test_runner, 5, "MAS", i)
	tick()

	expect_tick(test_runner, tick_index, 6)
	expect_signal(test_runner, 6, "MREQ", HIGH)
	expect_signal(test_runner, 6, "SEQ", HIGH)
	expect_signal(test_runner, 6, "OPC", LOW)
	expect_signal(test_runner, 6, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 6, "A", pc + 3 * L)
	expect_signal(test_runner, 6, "MAS", i)
	tick()

	expect_signal(test_runner, 6, "A", pc + 3 * L)
	tick()

	// Multiply Accumulate //
	accumulate, long = HIGH, LOW
	initialize()
	tick(times = 2)

	expect_tick(test_runner, tick_index, 1)
	gba_request_MAMAI_cycle(accumulate, long)
	memory_respond_MAMAI_cycle(accumulate, long)
	expect_signal(test_runner, 1, "MREQ", LOW)
	expect_signal(test_runner, 1, "SEQ", LOW)
	expect_signal(test_runner, 1, "OPC", HIGH)
	expect_signal(test_runner, 1, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 1, "A", pc + 8)
	expect_signal(test_runner, 1, "MAS", Memory_Access_Size.WORD)
	tick()

	expect_tick(test_runner, tick_index, 2)
	expect_signal(test_runner, 2, "MREQ", LOW)
	expect_signal(test_runner, 2, "SEQ", LOW)
	expect_signal(test_runner, 2, "OPC", HIGH)
	expect_signal(test_runner, 2, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 2, "A", pc + 8)
	expect_signal(test_runner, 2, "MAS", Memory_Access_Size.WORD)
	expect_signal(test_runner, 2, "DIN", memory_read_u32(pc + 8))
	tick()

	expect_tick(test_runner, tick_index, 3)
	expect_signal(test_runner, 3, "MREQ", LOW)
	expect_signal(test_runner, 3, "SEQ", LOW)
	expect_signal(test_runner, 3, "OPC", LOW)
	expect_signal(test_runner, 3, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 3, "A", pc + 8)
	expect_signal(test_runner, 3, "MAS", Memory_Access_Size.WORD)
	tick()

	expect_tick(test_runner, tick_index, 4)
	expect_signal(test_runner, 4, "MREQ", LOW)
	expect_signal(test_runner, 4, "SEQ", LOW)
	expect_signal(test_runner, 4, "OPC", LOW)
	expect_signal(test_runner, 4, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 4, "A", pc + 8)
	expect_signal(test_runner, 4, "MAS", Memory_Access_Size.WORD)
	tick()

	expect_tick(test_runner, tick_index, 5)
	expect_signal(test_runner, 5, "MREQ", LOW)
	expect_signal(test_runner, 5, "SEQ", LOW)
	expect_signal(test_runner, 5, "OPC", LOW)
	expect_signal(test_runner, 5, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 5, "A", pc + 12)
	expect_signal(test_runner, 5, "MAS", Memory_Access_Size.WORD)
	tick()

	expect_tick(test_runner, tick_index, 6)
	expect_signal(test_runner, 6, "MREQ", LOW)
	expect_signal(test_runner, 6, "SEQ", LOW)
	expect_signal(test_runner, 6, "OPC", LOW)
	expect_signal(test_runner, 6, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 6, "A", pc + 12)
	expect_signal(test_runner, 6, "MAS", Memory_Access_Size.WORD)
	tick()

	expect_tick(test_runner, tick_index, 7)
	expect_signal(test_runner, 7, "MREQ", HIGH)
	expect_signal(test_runner, 7, "SEQ", HIGH)
	expect_signal(test_runner, 7, "OPC", LOW)
	expect_signal(test_runner, 7, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 7, "A", pc + 12)
	expect_signal(test_runner, 7, "MAS", Memory_Access_Size.WORD)
	tick()

	expect_tick(test_runner, tick_index, 8)
	expect_signal(test_runner, 8, "MREQ", HIGH)
	expect_signal(test_runner, 8, "SEQ", HIGH)
	expect_signal(test_runner, 8, "OPC", LOW)
	expect_signal(test_runner, 8, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 8, "A", pc + 12)
	expect_signal(test_runner, 8, "MAS", Memory_Access_Size.WORD)
	tick()

	expect_signal(test_runner, 9, "A", pc + 12)
	tick()

	expect_signal(test_runner, 10, "A", pc + 12)
	tick()

	// Multiply Long //
	accumulate, long = LOW, HIGH
	initialize()
	tick(times = 2)

	expect_tick(test_runner, tick_index, 1)
	gba_request_MAMAI_cycle(accumulate, long)
	memory_respond_MAMAI_cycle(accumulate, long)
	expect_signal(test_runner, 1, "MREQ", LOW)
	expect_signal(test_runner, 1, "SEQ", LOW)
	expect_signal(test_runner, 1, "OPC", HIGH)
	expect_signal(test_runner, 1, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 1, "A", pc + 8)
	expect_signal(test_runner, 1, "MAS", i)
	tick()

	expect_tick(test_runner, tick_index, 2)
	expect_signal(test_runner, 2, "MREQ", LOW)
	expect_signal(test_runner, 2, "SEQ", LOW)
	expect_signal(test_runner, 2, "OPC", HIGH)
	expect_signal(test_runner, 2, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 2, "A", pc + 8)
	expect_signal(test_runner, 2, "MAS", i)
	expect_signal(test_runner, 2, "DIN", memory_read(pc + 8, i))
	tick()

	expect_tick(test_runner, tick_index, 3)
	expect_signal(test_runner, 3, "MREQ", LOW)
	expect_signal(test_runner, 3, "SEQ", LOW)
	expect_signal(test_runner, 3, "OPC", LOW)
	expect_signal(test_runner, 3, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 3, "A", pc + 12)
	expect_signal(test_runner, 3, "MAS", i)
	tick()

	expect_tick(test_runner, tick_index, 4)
	expect_signal(test_runner, 4, "MREQ", LOW)
	expect_signal(test_runner, 4, "SEQ", LOW)
	expect_signal(test_runner, 4, "OPC", LOW)
	expect_signal(test_runner, 4, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 4, "A", pc + 12)
	expect_signal(test_runner, 4, "MAS", i)
	tick()

	expect_tick(test_runner, tick_index, 5)
	expect_signal(test_runner, 5, "MREQ", HIGH)
	expect_signal(test_runner, 5, "SEQ", HIGH)
	expect_signal(test_runner, 5, "OPC", LOW)
	expect_signal(test_runner, 5, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 5, "A", pc + 12)
	expect_signal(test_runner, 5, "MAS", i)
	tick()

	expect_tick(test_runner, tick_index, 6)
	expect_signal(test_runner, 6, "MREQ", HIGH)
	expect_signal(test_runner, 6, "SEQ", HIGH)
	expect_signal(test_runner, 6, "OPC", LOW)
	expect_signal(test_runner, 6, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 6, "A", pc + 12)
	expect_signal(test_runner, 6, "MAS", i)
	tick()

	expect_signal(test_runner, 7, "A", pc + 12)
	tick()

	expect_signal(test_runner, 8, "A", pc + 12)
	tick()

	// Multiply Accumulate Long //
	accumulate, long = HIGH, HIGH
	initialize()
	tick(times = 2)

	expect_tick(test_runner, tick_index, 1)
	gba_request_MAMAI_cycle(accumulate, long)
	memory_respond_MAMAI_cycle(accumulate, long)
	expect_signal(test_runner, 1, "MREQ", LOW)
	expect_signal(test_runner, 1, "SEQ", LOW)
	expect_signal(test_runner, 1, "OPC", HIGH)
	expect_signal(test_runner, 1, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 1, "A", pc + 8)
	expect_signal(test_runner, 1, "MAS", Memory_Access_Size.WORD)
	tick()

	expect_tick(test_runner, tick_index, 2)
	expect_signal(test_runner, 2, "MREQ", LOW)
	expect_signal(test_runner, 2, "SEQ", LOW)
	expect_signal(test_runner, 2, "OPC", HIGH)
	expect_signal(test_runner, 2, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 2, "A", pc + 8)
	expect_signal(test_runner, 2, "MAS", Memory_Access_Size.WORD)
	expect_signal(test_runner, 2, "DIN", memory_read_u32(pc + 8))
	tick()

	expect_tick(test_runner, tick_index, 3)
	expect_signal(test_runner, 3, "MREQ", LOW)
	expect_signal(test_runner, 3, "SEQ", LOW)
	expect_signal(test_runner, 3, "OPC", LOW)
	expect_signal(test_runner, 3, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 3, "A", pc + 8)
	expect_signal(test_runner, 3, "MAS", Memory_Access_Size.WORD)
	tick()

	expect_tick(test_runner, tick_index, 4)
	expect_signal(test_runner, 4, "MREQ", LOW)
	expect_signal(test_runner, 4, "SEQ", LOW)
	expect_signal(test_runner, 4, "OPC", LOW)
	expect_signal(test_runner, 4, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 4, "A", pc + 8)
	expect_signal(test_runner, 4, "MAS", Memory_Access_Size.WORD)
	tick()

	expect_tick(test_runner, tick_index, 5)
	expect_signal(test_runner, 5, "MREQ", LOW)
	expect_signal(test_runner, 5, "SEQ", LOW)
	expect_signal(test_runner, 5, "OPC", LOW)
	expect_signal(test_runner, 5, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 5, "A", pc + 12)
	expect_signal(test_runner, 5, "MAS", Memory_Access_Size.WORD)
	tick()

	expect_tick(test_runner, tick_index, 6)
	expect_signal(test_runner, 6, "MREQ", LOW)
	expect_signal(test_runner, 6, "SEQ", LOW)
	expect_signal(test_runner, 6, "OPC", LOW)
	expect_signal(test_runner, 6, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 6, "A", pc + 12)
	expect_signal(test_runner, 6, "MAS", Memory_Access_Size.WORD)
	tick()

	expect_tick(test_runner, tick_index, 7)
	expect_signal(test_runner, 7, "MREQ", HIGH)
	expect_signal(test_runner, 7, "SEQ", HIGH)
	expect_signal(test_runner, 7, "OPC", LOW)
	expect_signal(test_runner, 7, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 7, "A", pc + 12)
	expect_signal(test_runner, 7, "MAS", Memory_Access_Size.WORD)
	tick()

	expect_tick(test_runner, tick_index, 8)
	expect_signal(test_runner, 8, "MREQ", HIGH)
	expect_signal(test_runner, 8, "SEQ", HIGH)
	expect_signal(test_runner, 8, "OPC", LOW)
	expect_signal(test_runner, 8, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 8, "A", pc + 12)
	expect_signal(test_runner, 8, "MAS", Memory_Access_Size.WORD)
	tick()

	expect_signal(test_runner, 9, "A", pc + 12)
	tick()

	expect_signal(test_runner, 10, "A", pc + 12)
	tick()

	if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = label), sep = "") }


@(test)
test_LRI_cycle:: proc(test_runner: ^testing.T) {
	using state: State
	label:: "LRI-Cycle"
	context = initialize_context(&state)
	allocate()
	alu: u32 = rand.uint32()
	pc_prim: u32 = rand.uint32()

	// normal //
	destination_is_pc: bool = false
	initialize()
	T: = gba_core.executing_thumb.output
	pc: = gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^
	L: u32 = gba_core.executing_thumb.output ? 2 : 4
	i: Memory_Access_Size = T ? .HALFWORD : .WORD
	s: = i
	tick(times = 2)

	expect_tick(test_runner, tick_index, 1)
	gba_request_LRI_cycle(alu, destination_is_pc, pc_prim)
	memory_respond_LRI_cycle(alu, destination_is_pc, pc_prim)
	expect_signal(test_runner, 1, "MREQ", HIGH)
	expect_signal(test_runner, 1, "SEQ", LOW)
	expect_signal(test_runner, 1, "OPC", HIGH)
	expect_signal(test_runner, 1, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 1, "A", pc + 2 * L)
	expect_signal(test_runner, 1, "MAS", i)
	tick()

	expect_tick(test_runner, tick_index, 2)
	expect_signal(test_runner, 2, "MREQ", HIGH)
	expect_signal(test_runner, 2, "SEQ", LOW)
	expect_signal(test_runner, 2, "OPC", HIGH)
	expect_signal(test_runner, 2, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 2, "A", pc + 2 * L)
	expect_signal(test_runner, 2, "MAS", i)
	expect_signal(test_runner, 2, "DIN", memory_read(pc + 2 * L, i))
	tick()

	expect_tick(test_runner, tick_index, 3)
	expect_signal(test_runner, 3, "MREQ", LOW)
	expect_signal(test_runner, 3, "SEQ", LOW)
	expect_signal(test_runner, 3, "OPC", LOW)
	expect_signal(test_runner, 3, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 3, "A", alu)
	expect_signal(test_runner, 3, "MAS", s)
	tick()

	expect_tick(test_runner, tick_index, 4)
	expect_signal(test_runner, 4, "MREQ", LOW)
	expect_signal(test_runner, 4, "SEQ", LOW)
	expect_signal(test_runner, 4, "OPC", LOW)
	expect_signal(test_runner, 4, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 4, "A", alu)
	expect_signal(test_runner, 4, "MAS", s)
	expect_signal(test_runner, 4, "DIN", memory_read(alu, s))
	tick()

	expect_tick(test_runner, tick_index, 5)
	expect_signal(test_runner, 5, "MREQ", HIGH)
	expect_signal(test_runner, 5, "SEQ", HIGH)
	expect_signal(test_runner, 5, "OPC", LOW)
	expect_signal(test_runner, 5, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 5, "A", pc + 3 * L)
	expect_signal(test_runner, 5, "MAS", i)
	tick()

	expect_tick(test_runner, tick_index, 6)
	expect_signal(test_runner, 6, "MREQ", HIGH)
	expect_signal(test_runner, 6, "SEQ", HIGH)
	expect_signal(test_runner, 6, "OPC", LOW)
	expect_signal(test_runner, 6, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 6, "A", pc + 3 * L)
	expect_signal(test_runner, 6, "MAS", i)
	tick()

	expect_signal(test_runner, 7, "A", pc + 3 * L)
	tick()

	expect_signal(test_runner, 8, "A", pc + 3 * L)
	tick()

	// dest=pc //
	destination_is_pc = true
	initialize()
	tick(times = 2)

	expect_tick(test_runner, tick_index, 1)
	gba_request_LRI_cycle(alu, destination_is_pc, pc_prim)
	memory_respond_LRI_cycle(alu, destination_is_pc, pc_prim)
	expect_signal(test_runner, 1, "MREQ", HIGH)
	expect_signal(test_runner, 1, "SEQ", LOW)
	expect_signal(test_runner, 1, "OPC", HIGH)
	expect_signal(test_runner, 1, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 1, "A", pc + 8)
	expect_signal(test_runner, 1, "MAS", Memory_Access_Size.WORD)
	tick()

	expect_tick(test_runner, tick_index, 2)
	expect_signal(test_runner, 2, "MREQ", HIGH)
	expect_signal(test_runner, 2, "SEQ", LOW)
	expect_signal(test_runner, 2, "OPC", HIGH)
	expect_signal(test_runner, 2, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 2, "A", pc + 8)
	expect_signal(test_runner, 2, "MAS", Memory_Access_Size.WORD)
	expect_signal(test_runner, 2, "DIN", memory_read_u32(pc + 8))
	tick()

	expect_tick(test_runner, tick_index, 3)
	expect_signal(test_runner, 3, "MREQ", LOW)
	expect_signal(test_runner, 3, "SEQ", LOW)
	expect_signal(test_runner, 3, "OPC", LOW)
	expect_signal(test_runner, 3, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 3, "A", alu)
	tick()

	expect_tick(test_runner, tick_index, 4)
	expect_signal(test_runner, 4, "MREQ", LOW)
	expect_signal(test_runner, 4, "SEQ", LOW)
	expect_signal(test_runner, 4, "OPC", LOW)
	expect_signal(test_runner, 4, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 4, "A", alu)
	expect_signal(test_runner, 4, "DIN", memory_read_u32(alu))
	tick()

	expect_tick(test_runner, tick_index, 5)
	expect_signal(test_runner, 5, "MREQ", HIGH)
	expect_signal(test_runner, 5, "SEQ", LOW)
	expect_signal(test_runner, 5, "OPC", LOW)
	expect_signal(test_runner, 5, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 5, "A", pc + 12)
	expect_signal(test_runner, 5, "MAS", Memory_Access_Size.WORD)
	tick()

	expect_tick(test_runner, tick_index, 6)
	expect_signal(test_runner, 6, "MREQ", HIGH)
	expect_signal(test_runner, 6, "SEQ", LOW)
	expect_signal(test_runner, 6, "OPC", LOW)
	expect_signal(test_runner, 6, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 6, "A", pc + 12)
	expect_signal(test_runner, 6, "MAS", Memory_Access_Size.WORD)
	tick()

	expect_tick(test_runner, tick_index, 7)
	expect_signal(test_runner, 7, "MREQ", HIGH)
	expect_signal(test_runner, 7, "SEQ", HIGH)
	expect_signal(test_runner, 7, "OPC", HIGH)
	expect_signal(test_runner, 7, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 7, "A", pc_prim)
	expect_signal(test_runner, 7, "MAS", Memory_Access_Size.WORD)
	tick()

	expect_tick(test_runner, tick_index, 8)
	expect_signal(test_runner, 8, "MREQ", HIGH)
	expect_signal(test_runner, 8, "SEQ", HIGH)
	expect_signal(test_runner, 8, "OPC", HIGH)
	expect_signal(test_runner, 8, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 8, "A", pc_prim)
	expect_signal(test_runner, 8, "MAS", Memory_Access_Size.WORD)
	expect_signal(test_runner, 8, "DIN", memory_read_u32(pc_prim))
	tick()

	expect_tick(test_runner, tick_index, 9)
	expect_signal(test_runner, 9, "MREQ", HIGH)
	expect_signal(test_runner, 9, "SEQ", HIGH)
	expect_signal(test_runner, 9, "OPC", HIGH)
	expect_signal(test_runner, 9, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 9, "A", pc_prim + 4)
	expect_signal(test_runner, 9, "MAS", Memory_Access_Size.WORD)
	tick()

	expect_tick(test_runner, tick_index, 10)
	expect_signal(test_runner, 10, "MREQ", HIGH)
	expect_signal(test_runner, 10, "SEQ", HIGH)
	expect_signal(test_runner, 10, "OPC", HIGH)
	expect_signal(test_runner, 10, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 10, "A", pc_prim + 4)
	expect_signal(test_runner, 10, "MAS", Memory_Access_Size.WORD)
	expect_signal(test_runner, 10, "DIN", memory_read_u32(pc_prim + 4))
	tick()

	expect_signal(test_runner, 11, "A", pc_prim + 8)
	tick()

	expect_signal(test_runner, 12, "A", pc_prim + 8)
	tick()

	if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = label), sep = "") }


@(test)
test_SRI_cycle:: proc(test_runner: ^testing.T) {
	using state: State
	label:: "SRI-Cycle"
	context = initialize_context(&state)
	allocate()
	alu: u32 = rand.uint32()
	Rd: u32 = rand.uint32()

	destination_is_pc: bool = false
	initialize()
	T: = gba_core.executing_thumb.output
	pc: = gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^
	L: u32 = gba_core.executing_thumb.output ? 2 : 4
	i: Memory_Access_Size = T ? .HALFWORD : .WORD
	s: = i
	tick(times = 2)

	expect_tick(test_runner, tick_index, 1)
	gba_request_SRI_cycle(alu, Rd)
	memory_respond_SRI_cycle(alu, Rd)
	// log.info(signal_tprint_queue(&memory.read_write))
	expect_signal(test_runner, 1, "MREQ", HIGH)
	expect_signal(test_runner, 1, "SEQ", LOW)
	expect_signal(test_runner, 1, "OPC", HIGH)
	expect_signal(test_runner, 1, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 1, "A", pc + 2 * L)
	expect_signal(test_runner, 1, "MAS", i)
	tick()

	// log.info(signal_tprint_queue(&memory.read_write))
	expect_tick(test_runner, tick_index, 2)
	expect_signal(test_runner, 2, "MREQ", HIGH)
	expect_signal(test_runner, 2, "SEQ", LOW)
	expect_signal(test_runner, 2, "OPC", HIGH)
	expect_signal(test_runner, 2, "RW", Memory_Read_Write.READ)
	expect_signal(test_runner, 2, "A", pc + 2 * L)
	expect_signal(test_runner, 2, "MAS", i)
	expect_signal(test_runner, 2, "DIN", memory_read(pc + 2 * L, i))
	tick()

	// log.info(signal_tprint_queue(&memory.read_write))
	expect_tick(test_runner, tick_index, 3)
	expect_signal(test_runner, 3, "MREQ", HIGH)
	expect_signal(test_runner, 3, "SEQ", LOW)
	expect_signal(test_runner, 3, "OPC", LOW)
	expect_signal(test_runner, 3, "RW", Memory_Read_Write.WRITE)
	expect_signal(test_runner, 3, "A", alu)
	expect_signal(test_runner, 3, "MAS", s)
	tick()

	// log.info(signal_tprint_queue(&memory.read_write))
	expect_tick(test_runner, tick_index, 4)
	expect_signal(test_runner, 4, "MREQ", HIGH)
	expect_signal(test_runner, 4, "SEQ", LOW)
	expect_signal(test_runner, 4, "OPC", LOW)
	expect_signal(test_runner, 4, "RW", Memory_Read_Write.WRITE)
	expect_signal(test_runner, 4, "A", alu)
	expect_signal(test_runner, 4, "MAS", s)
	expect_signal(test_runner, 4, "DIN", memory_read(alu, s))
	tick()

	if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = label), sep = "") }


@(test)
test_LMRI_cycle:: proc(test_runner: ^testing.T) {
	using state: State
	label:: "LMRI-Cycle"
	context = initialize_context(&state)

	if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = label), sep = "") }


@(test)
test_SMRI_cycle:: proc(test_runner: ^testing.T) {
	using state: State
	label:: "SMRI-Cycle"
	context = initialize_context(&state)

	if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = label), sep = "") }


@(test)
test_DSI_cycle:: proc(test_runner: ^testing.T) {
	using state: State
	label:: "DSI-Cycle"
	context = initialize_context(&state)

	if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = label), sep = "") }


@(test)
test_SIAEI_cycle:: proc(test_runner: ^testing.T) {
	using state: State
	label:: "SIAEI-Cycle"
	context = initialize_context(&state)

	if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = label), sep = "") }


@(test)
test_UDI_cycle:: proc(test_runner: ^testing.T) {
	using state: State
	label:: "UDI-Cycle"
	context = initialize_context(&state)

	if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = label), sep = "") }


@(test)
test_UEI_cycle:: proc(test_runner: ^testing.T) {
	using state: State
	label:: "UEI-Cycle"
	context = initialize_context(&state)

	if testing.failed(test_runner) || PRINT_ALL_TEST_TIMELINES do log.info("\n", timeline_print(name = label), sep = "") }


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


@(test)
timing_matrix:: proc(test_runner: ^testing.T) { }


@(test)
test_aprint_instruction:: proc(test_runner: ^testing.T) {
	using state: State
	context = initialize_context(&state)
	allocate()
	initialize()
	context.logger.options = { /*.Level*/ }
	log.info(aprint_instruction_info_header())
	log.info(aprint_instruction_info(0, 0, GBA_ADC_Instruction_Decoded{ cond = .PLUS, operand = 14, shifter_operand = 53, destination = gba_core.logical_registers.r4 }))
	log.info(aprint_instruction_info(0, 0, GBA_ADD_Instruction_Decoded{ cond = .PLUS, operand = 14, shifter_operand = 53, destination = gba_core.logical_registers.r4 }))
	log.info(aprint_instruction_info(0, 0, GBA_AND_Instruction_Decoded{ cond = .PLUS, operand = 14, shifter_operand = 53, destination = gba_core.logical_registers.r4 }))
	log.info(aprint_instruction_info(0, 0, GBA_B_Instruction_Decoded{ cond = .PLUS, target_address = 86 }))
	log.info(aprint_instruction_info(0, 0, GBA_BL_Instruction_Decoded{ cond = .PLUS, target_address = 86 }))
	log.info(aprint_instruction_info(0, 0, GBA_BIC_Instruction_Decoded{ cond = .PLUS, operand = 14, shifter_operand = 53, destination = gba_core.logical_registers.r4 }))
	log.info(aprint_instruction_info(0, 0, GBA_BX_Instruction_Decoded{ cond = .PLUS, target_address = 86, thumb_mode = true }))
	log.info(aprint_instruction_info(0, 0, GBA_CMN_Instruction_Decoded{ cond = .PLUS, operand = 14, shifter_operand = 53 }))
	log.info(aprint_instruction_info(0, 0, GBA_CMP_Instruction_Decoded{ cond = .PLUS, operand = 14, shifter_operand = 53 }))
	log.info(aprint_instruction_info(0, 0, GBA_EOR_Instruction_Decoded{ cond = .PLUS, operand = 14, shifter_operand = 53, destination = gba_core.logical_registers.r4 }))
	log.info(aprint_instruction_info(0, 0, GBA_LDM_Instruction_Decoded{ cond = .PLUS, destination_registers = { .R4, .R11, .CPSR }, start_address = 47 }))
	log.info(aprint_instruction_info(0, 0, GBA_LDR_Instruction_Decoded{ cond = .PLUS, destination = gba_core.logical_registers.r4, address = 47 }))
	log.info(aprint_instruction_info(0, 0, GBA_LDRB_Instruction_Decoded{ cond = .PLUS, destination = gba_core.logical_registers.r4, address = 47 }))
	log.info(aprint_instruction_info(0, 0, GBA_LDRBT_Instruction_Decoded{ cond = .PLUS, destination = gba_core.logical_registers.r4, address = 47 }))
	log.info(aprint_instruction_info(0, 0, GBA_LDRH_Instruction_Decoded{ cond = .PLUS, destination = gba_core.logical_registers.r4, address = 47 }))
	log.info(aprint_instruction_info(0, 0, GBA_LDRSB_Instruction_Decoded{ cond = .PLUS, destination = gba_core.logical_registers.r4, address = 47 }))
	log.info(aprint_instruction_info(0, 0, GBA_LDRSH_Instruction_Decoded{ cond = .PLUS, destination = gba_core.logical_registers.r4, address = 47 }))
	log.info(aprint_instruction_info(0, 0, GBA_LDRT_Instruction_Decoded{ cond = .PLUS, destination = gba_core.logical_registers.r4, address = 47 }))
	log.info(aprint_instruction_info(0, 0, GBA_MLA_Instruction_Decoded{ cond = .PLUS, operand = 14, multiplicand = 53, addend = 23, destination = gba_core.logical_registers.r4 }))
	log.info(aprint_instruction_info(0, 0, GBA_MOV_Instruction_Decoded{ cond = .PLUS, destination = gba_core.logical_registers.r4, shifter_operand = 32 }))
	log.info(aprint_instruction_info(0, 0, GBA_MRS_Instruction_Decoded{ cond = .PLUS, destination = gba_core.logical_registers.r4, source = gba_core.logical_registers.cpsr }))
	log.info(aprint_instruction_info(0, 0, GBA_MSR_Instruction_Decoded{ cond = .PLUS, destination = .CPSR, operand = 32 }))
	log.info(aprint_instruction_info(0, 0, GBA_MUL_Instruction_Decoded{ cond = .PLUS, operand = 14, multiplicand = 53, destination = gba_core.logical_registers.r4 }))
	log.info(aprint_instruction_info(0, 0, GBA_MVN_Instruction_Decoded{ cond = .PLUS, destination = gba_core.logical_registers.r4, shifter_operand = 32 }))
	log.info(aprint_instruction_info(0, 0, GBA_ORR_Instruction_Decoded{ cond = .PLUS, operand = 14, shifter_operand = 53, destination = gba_core.logical_registers.r4 }))
	log.info(aprint_instruction_info(0, 0, GBA_RSB_Instruction_Decoded{ cond = .PLUS, operand = 14, shifter_operand = 53, destination = gba_core.logical_registers.r4 }))
	log.info(aprint_instruction_info(0, 0, GBA_RSC_Instruction_Decoded{ cond = .PLUS, operand = 14, shifter_operand = 53, destination = gba_core.logical_registers.r4 }))
	log.info(aprint_instruction_info(0, 0, GBA_SMLAL_Instruction_Decoded{ cond = .PLUS, operand = 14, multiplicands = { 53, 19 }, destinations = { gba_core.logical_registers.r4, gba_core.logical_registers.r5 } }))
	log.info(aprint_instruction_info(0, 0, GBA_SMULL_Instruction_Decoded{ cond = .PLUS, operand = 14, multiplicands = { 53, 19 }, destinations = { gba_core.logical_registers.r4, gba_core.logical_registers.r5 } }))
	log.info(aprint_instruction_info(0, 0, GBA_STM_Instruction_Decoded{ cond = .PLUS, source_registers = { .R4, .R11, .CPSR }, start_address = 47 }))
	log.info(aprint_instruction_info(0, 0, GBA_STR_Instruction_Decoded{ cond = .PLUS, source = gba_core.logical_registers.r4, address = 47 }))
	log.info(aprint_instruction_info(0, 0, GBA_STRB_Instruction_Decoded{ cond = .PLUS, source = gba_core.logical_registers.r4, address = 47 }))
	log.info(aprint_instruction_info(0, 0, GBA_STRBT_Instruction_Decoded{ cond = .PLUS, source = gba_core.logical_registers.r4, address = 47 }))
	log.info(aprint_instruction_info(0, 0, GBA_STRH_Instruction_Decoded{ cond = .PLUS, source = gba_core.logical_registers.r4, address = 47 }))
	log.info(aprint_instruction_info(0, 0, GBA_STRT_Instruction_Decoded{ cond = .PLUS, source = gba_core.logical_registers.r4, address = 47 }))
	log.info(aprint_instruction_info(0, 0, GBA_SUB_Instruction_Decoded{ cond = .PLUS, operand = 14, shifter_operand = 53, destination = gba_core.logical_registers.r4 }))
	log.info(aprint_instruction_info(0, 0, GBA_SWI_Instruction_Decoded{ cond = .PLUS, immediate = 14 }))
	log.info(aprint_instruction_info(0, 0, GBA_SWP_Instruction_Decoded{ cond = .PLUS, source_register = gba_core.logical_registers.r4, destination_register = gba_core.logical_registers.r5 }))
	log.info(aprint_instruction_info(0, 0, GBA_SWPB_Instruction_Decoded{ cond = .PLUS, source_register = gba_core.logical_registers.r4, destination_register = gba_core.logical_registers.r5 }))
	log.info(aprint_instruction_info(0, 0, GBA_TEQ_Instruction_Decoded{ cond = .PLUS, operand = 14, shifter_operand = 53 }))
	log.info(aprint_instruction_info(0, 0, GBA_TST_Instruction_Decoded{ cond = .PLUS, operand = 14, shifter_operand = 53 }))
	log.info(aprint_instruction_info(0, 0, GBA_UMLAL_Instruction_Decoded{ cond = .PLUS, operand = 14, multiplicands = { 53, 19 }, destinations = { gba_core.logical_registers.r4, gba_core.logical_registers.r5 } }))
	log.info(aprint_instruction_info(0, 0, GBA_UMULL_Instruction_Decoded{ cond = .PLUS, operand = 14, multiplicands = { 53, 19 }, destinations = { gba_core.logical_registers.r4, gba_core.logical_registers.r5 } }))
	log.info(aprint_instruction_info(0, 0, GBA_Undefined_Instruction_Decoded{ })) }