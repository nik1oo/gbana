package gbana


Buttons:: struct { }
initialize_buttons:: proc() {
	using state: ^State = cast(^State)context.user_ptr }