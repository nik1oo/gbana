package gbana
import "base:runtime"
import "core:fmt"
import "core:testing"
import "core:math/rand"
import "core:os"
import "core:strings"
import "core:strconv"
import "core:log"
import "core:container/queue"
import "core:c/libc"


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


@(test)
test_decoder:: proc(test_runner: ^testing.T) {
	// 1. Write an ARMv4T assembly instruction.
	// 2. Compile to ARMv4T machine code using GNU ARM compiler arm-none-eabi-as.
	// 3. Decode instruction.
	// 4. Assert that the decoded instruction corresponds to the assembly code.
	using state: State
	context = initialize_context(&state)
	allocate()
	initialize()
	context.logger.options = { /*.Level*/ }

	assembly_instructions: [dynamic]string = make([dynamic]string)
	decoded_instructions_expect: [dynamic]GBA_Instruction_Decoded = make([dynamic]GBA_Instruction_Decoded)
	decoded_instructions_target: [dynamic]GBA_Instruction_Decoded = make([dynamic]GBA_Instruction_Decoded)

	// branch unconditionally to 16 //
	append(&assembly_instructions, "B 16")
	append(&decoded_instructions_expect, GBA_B_Instruction_Decoded {
		target_address =      16,
		cond =                .ALWAYS })

	// branch to 16 if carry flag is clear //
	append(&assembly_instructions, "BCC 16")
	append(&decoded_instructions_expect, GBA_B_Instruction_Decoded {
		target_address =      16,
		cond =                .CARRY_CLEAR })

	// branch to 16 if zero flag is set //
	append(&assembly_instructions, "BEQ 16")
	append(&decoded_instructions_expect, GBA_B_Instruction_Decoded {
		target_address =      16,
		cond =                .EQUAL })

	// R15 = 0, branch to location zero //
	append(&assembly_instructions, "MOV PC, #0")
	append(&decoded_instructions_expect, GBA_MOV_Instruction_Decoded {
		shifter_operand =     0,
		destination =         gba_core.logical_registers.array[GBA_Logical_Register_Name.PC],
		cond =                .ALWAYS })

	// subroutine call to function //
	append(&assembly_instructions, "BL 16")
	append(&decoded_instructions_expect, GBA_BL_Instruction_Decoded {
		target_address =      16,
		cond =                .ALWAYS })

	// R15=R14, return to instruction after the BL //
	append(&assembly_instructions, "MOV PC, LR")
	append(&decoded_instructions_expect, GBA_MOV_Instruction_Decoded {
		shifter_operand =     gba_core.logical_registers.array[GBA_Logical_Register_Name.LR]^,
		destination =         gba_core.logical_registers.array[GBA_Logical_Register_Name.PC],
		cond =                .ALWAYS })

	// store the address of the instruction after the next one into R14 ready to return //
	append(&assembly_instructions, "MOV LR, PC")
	append(&decoded_instructions_expect, GBA_MOV_Instruction_Decoded {
		shifter_operand =     gba_core.logical_registers.array[GBA_Logical_Register_Name.PC]^,
		destination =         gba_core.logical_registers.array[GBA_Logical_Register_Name.LR],
		cond =                .ALWAYS })

	// load a 32 bit value into the program counter //
	append(&assembly_instructions, "LDR PC, [R0]")
	append(&decoded_instructions_expect, GBA_LDR_Instruction_Decoded {
		address =             18,
		destination =         gba_core.logical_registers.array[GBA_Logical_Register_Name.PC],
		cond =                .ALWAYS })

	// Set R4 to value of R2 multiplied by R1
	append(&assembly_instructions, "MUL R4, R2, R1")
	append(&decoded_instructions_expect, GBA_MUL_Instruction_Decoded {
		operand =             transmute(i32)gba_core.logical_registers.r2^,
		multiplicand =        transmute(i32)gba_core.logical_registers.r1^,
		destination =         gba_core.logical_registers.r4,
		cond =                .ALWAYS })

	// R4 = R2 x R1, set N and Z flags //
	append(&assembly_instructions, "MULS R4, R2, R1")
	append(&decoded_instructions_expect, GBA_MUL_Instruction_Decoded {
		operand =             transmute(i32)gba_core.logical_registers.r2^,
		multiplicand =        transmute(i32)gba_core.logical_registers.r1^,
		destination =         gba_core.logical_registers.r4,
		set_condition_codes = true,
		cond =                .ALWAYS })

	// R7 = R8 x R9 + R3 //
	append(&assembly_instructions, "MLA R7, R8, R9, R3")
	append(&decoded_instructions_expect, GBA_MLA_Instruction_Decoded {
		operand =             transmute(i32)gba_core.logical_registers.r8^,
		multiplicand =        transmute(i32)gba_core.logical_registers.r9^,
		addend =              transmute(i32)gba_core.logical_registers.r3^,
		destination =         gba_core.logical_registers.r4,
		cond =                .ALWAYS })

	// R4 = bits 0 to 31 of R2 x R3, R8 = bits 32 to 63 of R2 x R3 //
	append(&assembly_instructions, "SMULL R4, R8, R2, R3")
	append(&decoded_instructions_expect, GBA_SMULL_Instruction_Decoded {
		operand =             transmute(i32)gba_core.logical_registers.r2^,
		// TODO There should be only 1 multiplicand, not 2. //
		multiplicands =       { transmute(i32)gba_core.logical_registers.r3^, transmute(i32)gba_core.logical_registers.r3^ },
		destinations =        { gba_core.logical_registers.r4, gba_core.logical_registers.r8 },
		cond =                .ALWAYS })

	// R6, R8 = R0 x R1 //
	append(&assembly_instructions, "UMULL R6, R8, R0, R1")
	append(&decoded_instructions_expect, GBA_UMULL_Instruction_Decoded {
		operand =             gba_core.logical_registers.r0^,
		multiplicands =       { gba_core.logical_registers.r1^, gba_core.logical_registers.r1^ },
		destinations =        { gba_core.logical_registers.r6, gba_core.logical_registers.r8 },
		cond =                .ALWAYS })

	// R5, R8 = R0 x R1 + R5, R8 //
	append(&assembly_instructions, "UMLAL R5, R8, R0, R1")
	append(&decoded_instructions_expect, GBA_UMLAL_Instruction_Decoded {
		operand =             gba_core.logical_registers.r0^,
		// TODO Where is the addend? Why isn't it decoded? //
		cond =                .ALWAYS })

	// Read the CPSR //
	append(&assembly_instructions, "MRS R0, CPSR")
	append(&decoded_instructions_expect, GBA_MRS_Instruction_Decoded {
		source =              gba_core.logical_registers.cpsr,
		destination =         gba_core.logical_registers.r0,
		cond =                .ALWAYS })

	// Clear the N, Z, C and V bits //
	append(&assembly_instructions, "BIC R0, R0, #0xf0000000")
	append(&decoded_instructions_expect, GBA_BIC_Instruction_Decoded {
		operand =             gba_core.logical_registers.r0^,
		shifter_operand =     0xf0000000,
		destination =         gba_core.logical_registers.r0,
		cond =                .ALWAYS })

	// update the flag bits in the CPSR, N, Z, C and V flags now all clear //
	append(&assembly_instructions, "MSR CPSR_f, R0")
	append(&decoded_instructions_expect, GBA_MSR_Instruction_Decoded {
		operand =             gba_core.logical_registers.r0^,
		destination =         .CPSR,
		field_mask =          { 3 }, // TODO Does CPSR_f refer to the lowest 8 or 4 bytes? Should the field mask have byte or bit precision? //
		cond =                .ALWAYS })

	// Read the CPSR //
	append(&assembly_instructions, "MRS R0, CPSR")
	append(&decoded_instructions_expect, GBA_MRS_Instruction_Decoded {
		source =              gba_core.logical_registers.cpsr,
		destination =         gba_core.logical_registers.r0,
		cond =                .ALWAYS })

	// Set the interrupt disable bit //
	append(&assembly_instructions, "ORR R0, R0, #0x80")
	append(&decoded_instructions_expect, GBA_ORR_Instruction_Decoded {
		operand =             gba_core.logical_registers.r0^,
		shifter_operand =     0x80,
		destination =         gba_core.logical_registers.r0,
		cond =                .ALWAYS })

	// Update the control bits in the CPSR, interrupts (IRQ) now disabled //
	append(&assembly_instructions, "MSR CPSR_c, R0")
	append(&decoded_instructions_expect, GBA_MSR_Instruction_Decoded {
		operand =             gba_core.logical_registers.r0^,
		destination =         .CPSR,
		field_mask =          { 0 },
		cond =                .ALWAYS })

	// Read the CPSR //
	append(&assembly_instructions, "MRS R0, CPSR")
	append(&decoded_instructions_expect, GBA_MRS_Instruction_Decoded {
		source =              gba_core.logical_registers.cpsr,
		destination =         gba_core.logical_registers.r0,
		cond =                .ALWAYS })

	// Clear the mode bits //
	append(&assembly_instructions, "BIC R0, R0, #0x1f")
	append(&decoded_instructions_expect, GBA_BIC_Instruction_Decoded {
		operand =             gba_core.logical_registers.r0^,
		shifter_operand =     0x1f,
		destination =         gba_core.logical_registers.r0,
		cond =                .ALWAYS })

	// Set the mode bits to FIQ mode //
	append(&assembly_instructions, "ORR R0, R0, #0x11")
	append(&decoded_instructions_expect, GBA_ORR_Instruction_Decoded {
		operand =             gba_core.logical_registers.r0^,
		shifter_operand =     0x11,
		destination =         gba_core.logical_registers.r0,
		cond =                .ALWAYS })

	// Update the control bits in the CPSR, now in FIQ mode //
	append(&assembly_instructions, "MSR CPSR_c, R0")
	append(&decoded_instructions_expect, GBA_MSR_Instruction_Decoded {
		operand =             gba_core.logical_registers.r0^,
		destination =         .CPSR,
		field_mask =          { 0 },
		cond =                .ALWAYS })

	// Load register 1 from the address in register 0 //
	append(&assembly_instructions, "LDR R1, [R0]")
	append(&decoded_instructions_expect, GBA_LDR_Instruction_Decoded {
		address =             gba_core.logical_registers.r0^,
		destination =         gba_core.logical_registers.r1,
		cond =                .ALWAYS })

	// Load R8 from the address in R3 + 4 //
	append(&assembly_instructions, "LDR R8, [R3, #4]")
	append(&decoded_instructions_expect, GBA_LDR_Instruction_Decoded {
		address =             gba_core.logical_registers.r3^ + 4,
		destination =         gba_core.logical_registers.r8,
		cond =                .ALWAYS })

	// Load R12 from R13 - 4 //
	append(&assembly_instructions, "LDR R12, [R13, #-4]")
	append(&decoded_instructions_expect, GBA_LDR_Instruction_Decoded {
		address =             gba_core.logical_registers.r13^ - 4,
		destination =         gba_core.logical_registers.r12,
		cond =                .ALWAYS })

	// Store R2 to the address in R1 + 0x100 //
	append(&assembly_instructions, "STR R2, [R1, #0x100]")
	append(&decoded_instructions_expect, GBA_STR_Instruction_Decoded {
		address =             gba_core.logical_registers.r1^ + 0x100,
		source =              gba_core.logical_registers.r2,
		cond =                .ALWAYS })

	// Load a byte into R5 from R9 (zero top 3 bytes) //
	append(&assembly_instructions, "LDRB R5, [R9]")
	append(&decoded_instructions_expect, GBA_LDR_Instruction_Decoded {
		address =             gba_core.logical_registers.r9^,
		destination =         gba_core.logical_registers.r5,
		unsigned_byte =       true,
		cond =                .ALWAYS })

	// Load byte to R3 from R8 + 3 (zero top 3 bytes) //
	append(&assembly_instructions, "LDRB R3, [R8, #3]")
	append(&decoded_instructions_expect, GBA_LDR_Instruction_Decoded {
		address =             gba_core.logical_registers.r8^ + 3,
		destination =         gba_core.logical_registers.r3,
		unsigned_byte =       true,
		cond =                .ALWAYS })

	// Store byte from R4 to R10 + 0x200 //
	append(&assembly_instructions, "STRB R4, [R10, #0x200]")
	append(&decoded_instructions_expect, GBA_STR_Instruction_Decoded {
		address =             gba_core.logical_registers.r10^ + 0x200,
		source =              gba_core.logical_registers.r4,
		unsigned_byte =       true,
		cond =                .ALWAYS })

	// Load R11 from the address in R1 + R2 //
	append(&assembly_instructions, "LDR R11, [R1, R2]")
	append(&decoded_instructions_expect, GBA_LDR_Instruction_Decoded {
		address =             gba_core.logical_registers.r1^ + gba_core.logical_registers.r2^,
		destination =         gba_core.logical_registers.r11,
		cond =                .ALWAYS })

	// Store byte from R10 to the address in R7 - R4 //
	append(&assembly_instructions, "STRB R10, [R7, -R4]")
	append(&decoded_instructions_expect, GBA_STR_Instruction_Decoded {
		address =             gba_core.logical_registers.r7^ - gba_core.logical_registers.r4^,
		source =              gba_core.logical_registers.r10,
		unsigned_byte =       true,
		cond =                .ALWAYS })

	// Load R11 from R3 + (R5 x 4) //
	append(&assembly_instructions, "LDR R11,[R3,R5,LSL #2]")
	append(&decoded_instructions_expect, GBA_LDR_Instruction_Decoded {
		address =             gba_core.logical_registers.r3^ + gba_core.logical_registers.r5^ * 4,
		destination =         gba_core.logical_registers.r11,
		cond =                .ALWAYS })

	// Load R1 from R0 + 4, then R0 = R0 + 4 //
	append(&assembly_instructions, "LDR R1, [R0, #4]!")
	append(&decoded_instructions_expect, GBA_LDR_Instruction_Decoded {
		address =             gba_core.logical_registers.r0^ + 4,
		destination =         gba_core.logical_registers.r1,
		cond =                .ALWAYS })

	// Store byte from R7 to R6 - 1, then R6 = R6 - 1 //
	append(&assembly_instructions, "STRB R7, [R6, #-1]!")
	append(&decoded_instructions_expect, GBA_STR_Instruction_Decoded {
		address =             gba_core.logical_registers.r6^ - 1,
		source =              gba_core.logical_registers.r7,
		unsigned_byte =       true,
		cond =                .ALWAYS })

	// Load R3 from R9, then R9 = R9 + 4 //
	append(&assembly_instructions, "LDR R3, [R9], #4")
	append(&decoded_instructions_expect, GBA_LDR_Instruction_Decoded {
		address =             gba_core.logical_registers.r9^ + 4,
		destination =         gba_core.logical_registers.r3,
		cond =                .ALWAYS })

	// Store word from R2 to R5, then R5 = R5 + 8 //
	append(&assembly_instructions, "STR R2, [R5], #8")
	append(&decoded_instructions_expect, GBA_STR_Instruction_Decoded {
		address =             gba_core.logical_registers.r5^ + 8,
		source =              gba_core.logical_registers.r2,
		cond =                .ALWAYS })

	// Load R0 from PC + 8 + 0x40 //
	append(&assembly_instructions, "LDR R0, [PC, #40]")
	append(&decoded_instructions_expect, GBA_LDR_Instruction_Decoded {
		address =             gba_core.logical_registers.pc^ + 8 + 0x40,
		destination =         gba_core.logical_registers.r0,
		cond =                .ALWAYS })

	// Load R0 from R1, then R1 = R1 + R2 //
	append(&assembly_instructions, "LDR R0, [R1], R2")
	append(&decoded_instructions_expect, GBA_LDR_Instruction_Decoded {
		address =             gba_core.logical_registers.r1^ + gba_core.logical_registers.r2^,
		destination =         gba_core.logical_registers.r1,
		cond =                .ALWAYS })

	// Load a halfword to R1 from R0 (zero top bytes) //
	append(&assembly_instructions, "LDRH R1, [R0]")
	append(&decoded_instructions_expect, GBA_LDRH_Instruction_Decoded {
		address =             gba_core.logical_registers.r0^,
		destination =         gba_core.logical_registers.r1,
		cond =                .ALWAYS })

	// Load a halfword into R8 from R3 + 2 //
	append(&assembly_instructions, "LDRH R8, [R3, #2]")
	append(&decoded_instructions_expect, GBA_LDRH_Instruction_Decoded {
		address =             gba_core.logical_registers.r3^ + 2,
		destination =         gba_core.logical_registers.r8,
		cond =                .ALWAYS })

	// Load a halfword R12 from R13 - 6 //
	append(&assembly_instructions, "LDRH R12, [R13, #-6]")
	append(&decoded_instructions_expect, GBA_LDRH_Instruction_Decoded {
		address =             gba_core.logical_registers.r13^ - 6,
		destination =         gba_core.logical_registers.r12,
		cond =                .ALWAYS })

	// Store halfword from R2 to R1 + 0x80 //
	append(&assembly_instructions, "STRH R2, [R1, #0x80]")
	append(&decoded_instructions_expect, GBA_STRH_Instruction_Decoded {
		address =             gba_core.logical_registers.r1^ + 0x80,
		source =              gba_core.logical_registers.r2,
		cond =                .ALWAYS })

	// Load signed halfword to R5 from R9 //
	append(&assembly_instructions, "LDRSH R5, [R9]")
	append(&decoded_instructions_expect, GBA_LDRSH_Instruction_Decoded {
		address =             gba_core.logical_registers.r9^,
		destination =         gba_core.logical_registers.r5,
		cond =                .ALWAYS })

	// Load signed byte to R3 from R8 + 3 //
	append(&assembly_instructions, "LDRSB R3, [R8, #3]")
	append(&decoded_instructions_expect, GBA_LDRSB_Instruction_Decoded {
		address =             gba_core.logical_registers.r8^ + 3,
		destination =         gba_core.logical_registers.r3,
		cond =                .ALWAYS })

	// Load signed byte to R4 from R10 + 0xc1 //
	append(&assembly_instructions, "LDRSB R4, [R10, #0xc1]")
	append(&decoded_instructions_expect, GBA_LDRSB_Instruction_Decoded {
		address =             gba_core.logical_registers.r10^ + 0xc1,
		destination =         gba_core.logical_registers.r4,
		cond =                .ALWAYS })

	// Load halfword R11 from the address in R1 + R2 //
	append(&assembly_instructions, "LDRH R11, [R1, R2]")
	append(&decoded_instructions_expect, GBA_LDRH_Instruction_Decoded {
		address =             gba_core.logical_registers.r1^ + gba_core.logical_registers.r2^,
		destination =         gba_core.logical_registers.r11,
		cond =                .ALWAYS })

	// Store halfword from R10 to R7 - R4 //
	append(&assembly_instructions, "STRH R10, [R7, -R4]")
	append(&decoded_instructions_expect, GBA_STRH_Instruction_Decoded {
		address =             gba_core.logical_registers.r7^ - gba_core.logical_registers.r4^,
		source =              gba_core.logical_registers.r10,
		cond =                .ALWAYS })

	// Load signed halfword R1 from R0+2,then R0=R0+2 //
	append(&assembly_instructions, "LDRSH R1, [R0, #2]!")
	append(&decoded_instructions_expect, GBA_LDRSH_Instruction_Decoded {
		address =             gba_core.logical_registers.r0^ + 2,
		destination =         gba_core.logical_registers.r1,
		cond =                .ALWAYS })

	// Load signed byte to R7 from R6-1, then R6=R6-1 //
	append(&assembly_instructions, "LDRSB R7, [R6, #-1]!")
	append(&decoded_instructions_expect, GBA_LDRSB_Instruction_Decoded {
		address =             gba_core.logical_registers.r6^ - 1,
		destination =         gba_core.logical_registers.r7,
		cond =                .ALWAYS })

	// Load halfword to R3 from R9, then R9 = R9 + 2 //
	append(&assembly_instructions, "LDRH R3, [R9], #2")
	append(&decoded_instructions_expect, GBA_LDRH_Instruction_Decoded {
		address =             gba_core.logical_registers.r9^ + 2,
		destination =         gba_core.logical_registers.r3,
		cond =                .ALWAYS })

	// Store halfword from R2 to R5, then R5 = R5 + 8 //
	append(&assembly_instructions, "STRH R2, [R5], #8")
	append(&decoded_instructions_expect, GBA_STRH_Instruction_Decoded {
		address =             gba_core.logical_registers.r5^ + 8,
		source =              gba_core.logical_registers.r2,
		cond =                .ALWAYS })

	// Stor multiple decrement before //
	append(&assembly_instructions, "STMFD R13!, {R0 - R12, LR}")
	append(&decoded_instructions_expect, GBA_STM_Instruction_Decoded {
		source_registers =    { .R0, .R1, .R2, .R3, .R4, .R5, .R6, .R7, .R8, .R9, .R10, .R11, .R12, .LR },
		start_address =       gba_core.logical_registers.r13^,
		cond =                .ALWAYS })

	// Load multiple decrement before //
	append(&assembly_instructions, "LDMFD R13!, {R0 - R12, PC}")
	append(&decoded_instructions_expect, GBA_LDM_Instruction_Decoded {
		destination_registers = { .R0, .R1, .R2, .R3, .R4, .R5, .R6, .R7, .R8, .R9, .R10, .R11, .R12, .PC },
		start_address =         gba_core.logical_registers.r13^,
		cond =                  .ALWAYS })

	// Load multiple increment after //
	append(&assembly_instructions, "LDMIA R0, {R5 - R8}")
	append(&decoded_instructions_expect, GBA_LDM_Instruction_Decoded {
		destination_registers = { .R5, .R6, .R7, .R8 },
		start_address =         gba_core.logical_registers.r0^,
		cond =                  .ALWAYS })

	// Store multiple decrement after //
	append(&assembly_instructions, "STMDA R1!, {R2, R5, R7 - R9, R11}")
	append(&decoded_instructions_expect, GBA_STM_Instruction_Decoded {
		source_registers =    { .R2, .R5, .R7, .R8, .R9, .R11 },
		start_address =       gba_core.logical_registers.r1^,
		cond =                .ALWAYS })

	// load R12 from address R9 and store R10 to address R9 //
	append(&assembly_instructions, "SWP R12, R10, [R9]")
	append(&decoded_instructions_expect, GBA_SWP_Instruction_Decoded {
		destination_register = gba_core.logical_registers.r10,
		source_register =      gba_core.logical_registers.r12,
		address =              gba_core.logical_registers.r9^,
		cond =                 .ALWAYS })

	// load byte to R3 from address R8 and store byte from R4 to address R8 //
	append(&assembly_instructions, "SWPB R3, R4, [R8]")
	append(&decoded_instructions_expect, GBA_SWPB_Instruction_Decoded {
		destination_register = gba_core.logical_registers.r3,
		source_register =      gba_core.logical_registers.r4,
		address =              gba_core.logical_registers.r8^,
		cond =                 .ALWAYS })

	// Exchange value in R1 and address in R2 //
	append(&assembly_instructions, "SWP R1, R1, [R2]")
	append(&decoded_instructions_expect, GBA_SWP_Instruction_Decoded {
		destination_register = gba_core.logical_registers.r1,
		source_register =      gba_core.logical_registers.r1,
		address =              gba_core.logical_registers.r2^,
		cond =                 .ALWAYS })

	asm_string: = strings.join(assembly_instructions[:], sep = "\n")
	os.write_entire_file("arm4_test.s", transmute([]u8)asm_string)
	libc.system("arm-none-eabi-as -march=armv4t -o arm4_test.o arm4_test.s")
	libc.system("arm-none-eabi-objdump --no-addresses -d arm4_test.o > arm4_test.dis")

	obj_bytes, ok: = os.read_entire_file("arm4_test.dis")
	testing.expect(test_runner, ok, "could not find disassembly file")
	if !ok do return
	obj_string: = string(obj_bytes)
	obj_string = strings.trim_right(obj_string, " \n\r\t")
	i: int = strings.index(obj_string, "<.text>:")
	lines: = strings.split_lines(obj_string[i + 10:])
	for &line, i in lines {
		line = strings.trim_left(line, "\t")
		line = line[0:strings.index_rune(line, ' ')] }
	// lines = lines[0:len(lines)-1]
	testing.expect(test_runner, len(lines) == len(assembly_instructions), "incorrect number of instructions in objdump")
	testing.expect(test_runner, len(lines) == len(decoded_instructions_expect), "incorrect number of instructions in objdump")

	for line, i in lines[0:8] {
		code, _: = strconv.parse_uint(line, 16)
		ins: GBA_Instruction = cast(GBA_Instruction)code
		ins_identified, _: = gba_identify_instruction(ins)
		ins_decoded: GBA_Instruction_Decoded
		defined: bool
		ins_decoded, defined = gba_decode_identified(ins_identified, 0)
		ins_decoded_expect: = decoded_instructions_expect[i]
		if ins_decoded_expect == ins_decoded {
			log.info(fmt.aprintf("%scorrect%s   %s", ANSI_GREEN, ANSI_RESET, aprint_instruction_info(0, ins, ins_decoded))) }
		else {
			log.info(fmt.aprintf("%sincorrect%s %s", ANSI_RED, ANSI_RESET, aprint_instruction_info(0, ins, ins_decoded)))
			log.info(fmt.aprintf("%sexpected%s  %s", ANSI_RED, ANSI_RESET, aprint_instruction_info(0, ins, ins_decoded_expect))) } }

	// i = strings.index(obj_string[])
	// ALT:
	// 1. Select machine code.
	// 2. decode machine code.
	// 3. Produce assembly from decoded OP-code.
	// 4. Compile to ARMv4T machine code using the GNU ARM compiler arm-none-eabi-as.
	// 5. Assert that the machine codes are identical.
}