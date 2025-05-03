package gbana
import "base:runtime"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:thread"
import "core:time"
import "vendor:glfw"
LOG:  string: "\e[0;36m[ log  ]\e[0m"
BAD:  string: "\e[0;31m[ bad  ]\e[0m"
WARN: string: "\e[0;33m[ warn ]\e[0m"
// - graphics hardware registers (GPU)
// - background registers (GPU)
// - windowing registers (GPU)
// - effects registers (GPU)
// - sound registers (sound)
// - DMA registers (DMA)
// - time registers (CPU)
// - serial communication registers (network)
// - keypad input & control registers (input)
// - interrupt registers (cpu)


// Stages of the tick:
// Transition - transition from the previous tick into the current tick.

LOW_PHASE:: 0
HIGH_PHASE:: 1
State:: struct {
	first_tick:           bool,
	tick_index:           uint,
	cycle_index:          uint,
	phase_index:          uint,
	timeline:             Timeline,
	signals:              [dynamic]Any_Signal,
	memory:               Memory,
	gba_core:             GBA_Core,
	gb_core:              GB_Core,
	bus_controller:       Bus_Controller,
	dma_controller:       DMA_Controller,
	ppu:                  PPU,
	sound_controller:     Sound_Controller,
	timer_controller:     Timer_Controller,
	interrupt_controller: Interrupt_Controller,
	input_controller:     Input_Controller,
	sio_controller:       SIO_Controller,
	oscillator:           Oscillator,
	speaker:              Speaker,
	display:              Display,
	buttons:              Buttons }
initialize_context:: proc(state: ^State) -> runtime.Context {
	context.user_ptr = state
	return context }
allocate:: proc() {
	allocate_memory() }
initialize:: proc() {
	using state: ^State = cast(^State)context.user_ptr
	first_tick = true
	tick_index = 0
	cycle_index = 0
	phase_index = 1
	signals = make([dynamic]Any_Signal)
	timeline = make(Timeline)
	initialize_memory()
	initialize_gba_core()
	initialize_gb_core()
	initialize_bus_controller()
	initialize_dma_controller()
	initialize_ppu()
	initialize_sound_controller()
	initialize_timer_controller()
	initialize_interrupt_controller()
	initialize_input_controller()
	initialize_sio_controller()
	initialize_oscillator()
	initialize_speaker()
	// initialize_display()
	initialize_buttons() }
	// device_reset() }
tick:: proc(n: uint = 0, times: int = 1) -> bool {
	using state: ^State = cast(^State)context.user_ptr
	current_tick_index: uint = tick_index
	current_cycle_index: uint = cycle_index
	current_phase_index: uint = phase_index
	if (n != 0) && (cycle_index >= n) do return false
	defer {
		if times > 1 do tick(times = times - 1) }
	if first_tick {
		first_tick = false
		return true }
	if phase_index == 1 {
		cycle_index += 1
		phase_index = 0 }
	else do phase_index += 1
	tick_index += 1
	signals_tick(current_tick_index, current_cycle_index, current_phase_index)
	return true }
main:: proc() {
	using state: State
	context = initialize_context(&state)
	allocate()
	initialize()
	memory_thread: = thread.create(memory_thread_proc)
	gba_core_thread: = thread.create(gba_core_thread_proc)
	gb_core_thread: = thread.create(gb_core_thread_proc)
	bus_controller_thread: = thread.create(bus_controller_thread_proc)
	dma_controller_thread: = thread.create(dma_controller_thread_proc)
	ppu_thread: = thread.create(ppu_thread_proc)
	sound_controller_thread: = thread.create(sound_controller_thread_proc)
	timer_controller_thread: = thread.create(timer_controller_thread_proc)
	interrupt_controller_thread: = thread.create(interrupt_controller_thread_proc)
	input_controller_thread: = thread.create(input_controller_thread_proc)
	sio_controller_thread: = thread.create(sio_controller_thread_proc)
	oscillator_thread: = thread.create(oscillator_thread_proc)
	speaker_thread: = thread.create(speaker_thread_proc)
	display_thread: = thread.create(display_thread_proc)
	buttons_thread: = thread.create(buttons_thread_proc)
	thread.start(memory_thread)
	thread.start(gba_core_thread)
	thread.start(gb_core_thread)
	thread.start(bus_controller_thread)
	thread.start(dma_controller_thread)
	thread.start(ppu_thread)
	thread.start(sound_controller_thread)
	thread.start(timer_controller_thread)
	thread.start(interrupt_controller_thread)
	thread.start(input_controller_thread)
	thread.start(sio_controller_thread)
	thread.start(oscillator_thread)
	thread.start(speaker_thread)
	thread.start(display_thread)
	thread.start(buttons_thread)
	for tick(n = 8) { }
	// time.sleep(10 * time.Second)
	thread.join(memory_thread)
	thread.join(gba_core_thread)
	thread.join(gb_core_thread)
	thread.join(bus_controller_thread)
	thread.join(dma_controller_thread)
	thread.join(ppu_thread)
	thread.join(sound_controller_thread)
	thread.join(timer_controller_thread)
	thread.join(interrupt_controller_thread)
	thread.join(input_controller_thread)
	thread.join(sio_controller_thread)
	thread.join(oscillator_thread)
	thread.join(speaker_thread)
	thread.join(display_thread)
	thread.join(buttons_thread)
	fmt.println(timeline_print()) }