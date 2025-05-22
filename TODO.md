
- Write tests for all instructions, to make sure they're correctly decoded and executed.

- Correct the instruction decoder until the following instructions appear in the BIOS:

	00000018  b      128h                ;IRQ vector: jump to actual BIOS handler
	00000128  stmfd  r13!,r0-r3,r12,r14  ;save registers to SP_irq
	0000012C  mov    r0,4000000h         ;ptr+4 to 03FFFFFC (mirror of 03007FFC)
	00000130  add    r14,r15,0h          ;retadr for USER handler $+8=138h
	00000134  ldr    r15,[r0,-4h]        ;jump to [03FFFFFC] USER handler
	00000138  ldmfd  r13!,r0-r3,r12,r14  ;restore registers from SP_irq
	0000013C  subs   r15,r14,4h          ;return from IRQ (PC=LR-4, CPSR=SPSR)

	0x00: SoftReset

	Resets the GBA and runs the code at address 0x2000000 or 0x8000000 depending on the contents of 0x3007ffa (0 means 0x8000000 and anything else means 0x2000000).

	0x01: RegisterRamReset

	Performs a selective reset of memory and I/O registers.
	Input: r0 = reset flags

	0x02: Halt

	Halts CPU execution until an interrupt occurs.

	0x03: Stop

	Stops the CPU and LCD until the enabled interrupt (keypad, cartridge or serial) occurs.

	0x04: IntrWait

	Waits for the given interrupt to happen.
	Input: r0 = initial flag clear, r1 = interrupt to wait

	0x05: VBlankIntrWait

	Waits for vblank to occur. Waits based on interrupt rather than polling in order to save battery power.
	Equivalent of calling IntrWait with r0=1 and r1=1.

	0x06: Div

	Input: r0 = numerator, r1 = denominator
	Output: r0 = numerator/denominator
	r1 = numerator % denominator;
	r3 = abs (numerator/denominator)

	0x07: DivArm

	Input: r0 = denominator, r1 = numerator
	Output: r0 = numerator/denominator
	r1 = numerator % denominator;
	r3 = abs (numerator/denominator)
	Note: For compatibility with ARM's library only. Slightly slower than SWI 6.

	0x08: Sqrt

	Input: r0 = unsigned 32-bit number
	Output: r0 = sqrt(number) (unsigned 32-bit integer)

	0x09: ArcTan

	Input: r0 = Tangent(angle) (16-bit; 1 bit sign, 1 bit integral, 14 bit decimal)
	Output: r0 = "-PI/2<THETA/<PI/2" in a range of 0xC000h-0x4000.
	Note: There is a problem in accuracy with "THETA<-PI/4, PI/4<THETA"