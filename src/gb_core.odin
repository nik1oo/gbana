package gbana


GB_Core:: struct { }
initialize_gb_core:: proc() {
	using state: ^State = cast(^State)context.user_ptr }