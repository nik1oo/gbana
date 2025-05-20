package gbana
import "core:thread"
import "core:sync"


// REGISTERS //
DMA0SAD:: u32
DMA1SAD:: DMA0SAD
DMA2SAD:: DMA0SAD
DMA3SAD:: DMA0SAD
DMA0DAD:: u32
DMA1DAD:: DMA0DAD
DMA2DAD:: DMA0DAD
DMA3DAD:: DMA0DAD
DMA0CNT_L:: u16
DMA1CNT_L:: DMA0CNT_L
DMA2CNT_L:: DMA0CNT_L
DMA3CNT_L:: DMA0CNT_L
DMA0CNT_H:: bit_field u16 {
	_:                          int                                                    | 5,
	dest_addr_control:          enum { Increment, Decrement, Fixed, Increment_Reload } | 2,
	source_adr_control:         enum { Increment, Decrement, Fixed, Prohibited }       | 2,
	dma_repeat:                 bool                                                   | 1,
	dma_transfer_type:          enum { Bit_16, Bit_32 }                                | 1,
	game_pak_drq:               bool                                                   | 1,
	dma_start_timing:           enum { Immediately, V_Blank, H_Blank, Special }        | 2,
	irq_upon_end_of_word_count: bool                                                   | 1,
	dma_enable:                 bool                                                   | 1 }
DMA1CNT_H:: DMA0CNT_H
DMA2CNT_H:: DMA0CNT_H
DMA3CNT_H:: DMA0CNT_H


DMA_Controller:: struct {
	mutex: sync.Recursive_Mutex }
initialize_dma_controller:: proc() {
	using state: ^State = cast(^State)context.user_ptr
	sync.recursive_mutex_lock(&dma_controller.mutex); defer sync.recursive_mutex_unlock(&dma_controller.mutex) }


// THREAD //
dma_controller_thread_proc:: proc(t: ^thread.Thread) { }