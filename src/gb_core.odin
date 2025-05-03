package gbana
import "core:thread"


GB_Core:: struct { }
initialize_gb_core:: proc() {
	using state: ^State = cast(^State)context.user_ptr }


// THREAD //
gb_core_thread_proc:: proc(t: ^thread.Thread) { }