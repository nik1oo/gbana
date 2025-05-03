package gbana
import "core:thread"


Buttons:: struct { }
initialize_buttons:: proc() {
	using state: ^State = cast(^State)context.user_ptr }


// THREAD //
buttons_thread_proc:: proc(t: ^thread.Thread) { }