B 16
BCC 16
BEQ 16
MOV PC, #0
BL 16
MOV PC, LR
MOV LR, PC
LDR PC, [R0]
MUL R4, R2, R1
MULS R4, R2, R1
MLA R7, R8, R9, R3
SMULL R4, R8, R2, R3
UMULL R6, R8, R0, R1
UMLAL R5, R8, R0, R1
MRS R0, CPSR
BIC R0, R0, #0xf0000000
MSR CPSR_f, R0
MRS R0, CPSR
ORR R0, R0, #0x80
MSR CPSR_c, R0
MRS R0, CPSR
BIC R0, R0, #0x1f
ORR R0, R0, #0x11
MSR CPSR_c, R0
LDR R1, [R0]
LDR R8, [R3, #4]
LDR R12, [R13, #-4]
STR R2, [R1, #0x100]
LDRB R5, [R9]
LDRB R3, [R8, #3]
STRB R4, [R10, #0x200]
LDR R11, [R1, R2]
STRB R10, [R7, -R4]
LDR R11,[R3,R5,LSL #2]
LDR R1, [R0, #4]!
STRB R7, [R6, #-1]!
LDR R3, [R9], #4
STR R2, [R5], #8
LDR R0, [PC, #40]
LDR R0, [R1], R2
LDRH R1, [R0]
LDRH R8, [R3, #2]
LDRH R12, [R13, #-6]
STRH R2, [R1, #0x80]
LDRSH R5, [R9]
LDRSB R3, [R8, #3]
LDRSB R4, [R10, #0xc1]
LDRH R11, [R1, R2]
STRH R10, [R7, -R4]
LDRSH R1, [R0, #2]!
LDRSB R7, [R6, #-1]!
LDRH R3, [R9], #2
STRH R2, [R5], #8
STMFD R13!, {R0 - R12, LR}
LDMFD R13!, {R0 - R12, PC}
LDMIA R0, {R5 - R8}
STMDA R1!, {R2, R5, R7 - R9, R11}
SWP R12, R10, [R9]
SWPB R3, R4, [R8]
SWP R1, R1, [R2]