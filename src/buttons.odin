package gbana
import "core:thread"
import "core:sync"


Buttons:: struct {
	mutex: sync.Recursive_Mutex }
initialize_buttons:: proc() {
	using state: ^State = cast(^State)context.user_ptr
	sync.recursive_mutex_lock(&buttons.mutex); defer sync.recursive_mutex_unlock(&buttons.mutex) }


// THREAD //
buttons_thread_proc:: proc(t: ^thread.Thread) { }