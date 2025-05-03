package gbana
import "core:thread"


Interrupt_Controller:: struct { }
initialize_interrupt_controller:: proc() {
	using state: ^State = cast(^State)context.user_ptr }


// THREAD //
interrupt_controller_thread_proc:: proc(t: ^thread.Thread) { }