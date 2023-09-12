.section .data

operands: .word 0x001b0000, 0x805a0000

sign: .word 0x80000000
exp: .word 0x7ff80000
mantissa: .word 0x0007ffff

.section .text
.global _start

store:
@ Store the result into r1 memory location.
stmfd sp!, {lr}
str r0, [r1]
ldmfd sp!, {pc}

nfpAdd:
stmfd sp!, {r0, r2-r11, lr}

@ Bit mask to obtain bit pattern only containing the sign bit. (32nd bit)
ldr r0, =sign
ldr r0, [r0]
ldr r2, [r1], #4
and r3, r2, r0

@ Bit mask to obtain bit pattern only containing the exponent. (31 - 20 bits)
ldr r0, =exp
ldr r0, [r0]
and r4, r2, r0

@ Bit mask to obtain bit pattern only containing the mantissa (19-1) bits.
ldr r0, =mantissa
ldr r0, [r0]
and r5, r2, r0

@ Same operations done for second operand.
ldr r2, [r1], #4
ldr r0, =sign
ldr r0, [r0]
and r6, r2, r0

ldr r0, =exp
ldr r0, [r0]
and r7, r2, r0

ldr r0, =mantissa
ldr r0, [r0]
and r8, r2, r0

@ Add 1 bit at the 20th bit location to convert mantissa into significand.
mov r9, #0b000000000010000000000000000000
add r5, r5, r9
add r8, r8, r9

@ Conditionally take 2's complement of mantissa if sign bit is 1.
tst r3, #0x80000000
beq b1
mov r9, #0b11111111111111111111111111111111
eor r5, r5, r9
add r8, r8, #1
b1:
tst r6, #0x80000000
beq b2
mov r9, #0b11111111111111111111111111111111
eor r8, r8, r9
add r8, r8, #1

b2:
asr r4, #19 @ exponent 1
asr r7, #19 @ exponent 2

@ Both the exponents are compared and the greater is selected for the answer.
cmp r4, r7
moveq r0, r4
movgt r0, r4
movlt r0, r7

lsl r0, #19

@ The mantissa bits are shifted for addition using the difference of the exponents.
subgt r9, r4, r7
asrgt r8, r9
sublt r9, r7, r4
asrlt r5, r9

@ Addition of the significands.
add r2, r5, r8

ands r11, r2, #0x80000000
beq signed
@ Take 2's complement of the result if it is negative.
mov r10, #-1
mul r2, r2, r10

signed:
@ If 21st bit is 1, then normalization is done by shifting to right by one.
@ else a loop is used to find the first 1 bit to perform normalization
@ exponent is modified accordingly
mov r10, #0b0000000000100000000000000000000
tst r2, r10
lsr r10, #1
beq b3
lsr r2, #1
add r0, r0, #0b00000000000010000000000000000000
b b4

b3:
tst r2, r10
bne b4
lsl r2, #1
sub r0, r0, #0b00000000000010000000000000000000
b b3

b4:
@ Combine all the parts of the result in register r0 to form a 32 bit floating point representation.
and r0, #0x7fffffff
ldr r10, =mantissa
ldr r10, [r10]
and r2, r2, r10

orr r0, r11, r0 
orr r0, r0, r2
bl store
ldmfd sp!, {r0, r2-r11, pc}

nfpMultiply:
stmfd sp!, {r0, r2-r12, lr}
@ Bit masking is used to extract sign, exponent and mantissa bits.
ldr r0, =sign
ldr r0, [r0]
ldr r2, [r1], #4
and r3, r2, r0

ldr r0, =exp
ldr r0, [r0]
and r4, r2, r0

ldr r0, =mantissa
ldr r0, [r0]
and r5, r2, r0

ldr r2, [r1], #4
ldr r0, =sign
ldr r0, [r0]
and r6, r2, r0

ldr r0, =exp
ldr r0, [r0]
and r7, r2, r0

ldr r0, =mantissa
ldr r0, [r0]
and r8, r2, r0

@ The sign of the result is determined by performing or operation on sign bits of operands.
eor r6, r6, r3
add r0, r4, r7

@ Mantissa is converted to significand by adding 1 at the 20th position.
mov r9, #0b00000000000010000000000000000000
add r5, r5, r9
add r8, r8, r9

@ The multiplication of two 20 bits sized numbers is obtained in two registers 32 bits each r11 and r10.
@ The first 24 bits of r10 are unused hence discarded and last 8 bits of r11 are truncated.
umull r11, r10, r5, r8
lsr r11, #8
lsl r10, #24
add r10, r10, r11
mov r12, #0b01111111111111111111111111111111
@ The sign bit of multiplication result is obtained using bics in r7 and removed from r10.
bics r7, r10, r12
and r10, r10, r12
add r0, r0, #0b10000000000000000000
mov r9, #12

bne notRenormalisation
lsr r12, #1
and r10, r10, r12
lsl r10, #1

notRenormalisation:
lsr r10, r9

@ Sign bit, exponent and significands parts are combined to obtain the result in r0 which is then
@ stored in memory.
orr r9, r6, r0
orr r0, r9, r10
bl store
ldmfd sp!, {r0, r2-r10, pc}

_start:
ldr r1, =operands
bl nfpMultiply
