    area    lab2, code, readwrite   
    export  hamming
    export  div
    
hamming
        stmfd r13!, {r1-r12, r14}

        ; Your code for the hamming routine goes here.  
        ; The argument (8-bit hamming code) is passed in r0. 
        ; The corrected data (or -1 if uncorrectable) is returned in r0.

        ldmfd r13!, {r1-r12, r14}
        bx lr      ; Return to the C program    

div
        stmfd r13!, {r1-r12, r14}

        ; r0 - dividend
        ; r1 - divisor
        ; r2 - quotient
        ; r3 - remainder
        ; r4 - counter
        mov r2, #0 ; initialize quotient to 0
        mov r3, r0 ; initialize remainder to dividend
        mov r4, #0x10 ; initialize counter to 16
        mov r1, r1, LSL #0x10 ; logical left shift divisor 16 places
cloop   sub r3, r3, r1 ; remainder = remainder - divisor; cloop is the counter loop
        cmp r3, #0 ; remainder < 0
        blt rless
        mov r2, r2, LSL #1 ; left shift quotient
        add r2, r2, #1 ; lsb = 1
shiftd  mov r1, r1, LSR #1 ; right shift divisor, msb = 0

        cmp r4, #0 ; counter > 0
        bgt decount

        mov r0, r2

        ldmfd r13!, {r1-r12, r14}
        bx lr      ; Return to the C program    

decount sub r4, r4, #1 ; decrement counter
        b cloop

rless   add r3, r3, r1 ; remainder = remainder + divisor
        mov r2, r2, LSL #1 ; left shift quotient, lsb = 0
        b shiftd

        end
