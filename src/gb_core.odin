package gbana
import "core:thread"
import "core:sync"


GB_Core:: struct {
	mutex: sync.Recursive_Mutex }
initialize_gb_core:: proc() {
	using state: ^State = cast(^State)context.user_ptr
	sync.recursive_mutex_lock(&gb_core.mutex); defer sync.recursive_mutex_unlock(&gb_core.mutex) }


// THREAD //
gb_core_thread_proc:: proc(t: ^thread.Thread) { }