package gbana
import "core:thread"


Speaker:: struct { }
initialize_speaker:: proc() {
	using state: ^State = cast(^State)context.user_ptr }


// THREAD //
speaker_thread_proc:: proc(t: ^thread.Thread) { }