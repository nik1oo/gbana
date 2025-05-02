package gbana


Speaker:: struct { }
initialize_speaker:: proc() {
	using state: ^State = cast(^State)context.user_ptr }