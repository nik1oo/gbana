package gbana
import "core:thread"


Timer_Controller:: struct { }
initialize_timer_controller:: proc() {
	using state: ^State = cast(^State)context.user_ptr }


// REGISTERS //
TM0CNT_L:: u16
TM1CNT_L:: TM0CNT_L
TM2CNT_L:: TM0CNT_L
TM3CNT_L:: TM0CNT_L
TM0CNT_H:: bit_field u16 {
	prescaler_selection: enum{ F_1, F_64, F_256, F_1024 } | 2,
	count_up_timing:     bool                             | 1,
	_:                   int                              | 3,
	timer_irq_enable:    bool                             | 1,
	timer_start_stop:    bool                             | 1,
	_:                   int                              | 8 }
TM1CNT_H:: TM0CNT_H
TM2CNT_H:: TM0CNT_H
TM3CNT_H:: TM0CNT_H


// THREAD //
timer_controller_thread_proc:: proc(t: ^thread.Thread) { }


// 16.78 MHz = 16.777.216 cy/s
// 59.727500569606 fr/s
// 16,777,216 / 59.727 = 280,896 cy/fr
// 16.74270 ms/fr
CYCLES_PER_FRAME:  f32 : 280_895.9999999992134946289062522
SECONDS_PER_FRAME: f32 : 0.0167427062988280781206267420204