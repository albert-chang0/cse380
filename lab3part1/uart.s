    area    serial, code, readwrite 
    export lab3
    
u0lsr equ 0x14          ; UART0 line status register

lab3
        stmfd sp!,{lr}  ; Store register lr on stack

        bl read_character
        bl output_character

        ldmfd sp!, {lr} ; Restore register lr from stack    
        bx lr

read_character
        stmfd sp!, {r1-r12, lr}

        ldr r2, =0xe000c000

rpoll   ldr r1, [r2, #u0lsr]    ; load status register
        and r1, r1, #1          ; test RDR in status register
        cmp r1, #0
        beq rpoll

        ldrb r0, [r2]

        ldmfd sp!, {r1-r12, lr}
        bx lr

output_character
        stmfd sp!, {r1-r12, lr}

        ldr r2, =0xe000c000 ; UART0 base address

tpoll   ldr r1, [r2, #u0lsr]    ; load status register
        and r1, r1, #0x20       ; test THRE in status register
        cmp r1, #0              ; poll until something is written
        beq tpoll

        strb r0, [r2]    ; write whatever is written to UART register

        ldmfd sp!, {r1-r12, lr}
        bx lr

        end
