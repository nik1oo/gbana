package gbana
import "core:thread"


// BUS CYCLE TYPES //
Bus_Cycle_Type:: enum {
	NON_SEQUENTIAL_TRANSFER,
	SEQUENTIAL_TRANSFER,
	INTERNAL,
	N_CYCLE = NON_SEQUENTIAL_TRANSFER,
	S_CYCLE = SEQUENTIAL_TRANSFER,
	I_CYCLE = INTERNAL }
Burst_Transfer_Type:: enum {
	WORD = 4,      // Increment address by 4. //
	HALFWORD = 2 } // Increment address by 2. //
gba_set_bus_cycle_type:: proc(state: ^State, type: Bus_Cycle_Type) {
	using state
	switch type {
	case .NON_SEQUENTIAL_TRANSFER: signal_force(&memory.memory_request, true);  signal_force(&memory.sequential_cycle, false)
	case .SEQUENTIAL_TRANSFER:     signal_force(&memory.memory_request, true);  signal_force(&memory.sequential_cycle, true)
	case .INTERNAL:                signal_force(&memory.memory_request, false); signal_force(&memory.sequential_cycle, false) } }
get_get_bus_cycle_type:: proc(state: ^State) -> Bus_Cycle_Type {
	using state
	switch {
	case (memory.memory_request.output == true)  && (memory.sequential_cycle.output == false): return .NON_SEQUENTIAL_TRANSFER
	case (memory.memory_request.output == true)  && (memory.sequential_cycle.output == true):  return .SEQUENTIAL_TRANSFER
	case (memory.memory_request.output == false) && (memory.sequential_cycle.output == false): return .INTERNAL }
	return auto_cast 0 }


// BUS CONTROLLER //
Bus_Controller:: struct {
	bus_cycle_type: Bus_Cycle_Type }
initialize_bus_controller:: proc() {
	using state: ^State = cast(^State)context.user_ptr }
tick_bus_controller_phase_1:: proc(state: ^State) {
	using state: ^State = cast(^State)context.user_ptr
	bus_controller.bus_cycle_type = get_get_bus_cycle_type(state)
	switch bus_controller.bus_cycle_type {
	case .NON_SEQUENTIAL_TRANSFER:
		address: = memory.address.output
	case .SEQUENTIAL_TRANSFER:
	case .INTERNAL:
	} }
tick_bus_controller_phase_2:: proc() {}


// THREAD //
bus_controller_thread_proc:: proc(t: ^thread.Thread) { }