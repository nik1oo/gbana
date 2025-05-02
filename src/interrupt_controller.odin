package gbana


Interrupt_Controller:: struct { }
initialize_interrupt_controller:: proc() {
	using state: ^State = cast(^State)context.user_ptr }