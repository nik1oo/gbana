package gbana
import "core:thread"
import "core:sync"


Speaker:: struct {
	mutex: sync.Recursive_Mutex }
initialize_speaker:: proc() {
	using state: ^State = cast(^State)context.user_ptr
	sync.recursive_mutex_lock(&speaker.mutex); defer sync.recursive_mutex_unlock(&speaker.mutex) }


// THREAD //
speaker_thread_proc:: proc(t: ^thread.Thread) { }