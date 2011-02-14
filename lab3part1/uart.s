    area    serial, code, readwrite 
    export lab3
    
u0lsr equ 0x14          ; UART0 line status register

lab3
        stmfd sp!,{lr}  ; Store register lr on stack

        ;bl read_character
        mov r0, #0x41
        bl output_character

        ldmfd sp!, {lr} ; Restore register lr from stack    
        bx lr

read_character
        stmfd sp!, {r1, r2, lr}

        ldr r2, =0xe000c000     ; UART0 base address

rpoll   ldrb r1, [r2, #u0lsr]   ; load status register
        and r1, r1, #1          ; test RDR
        cmp r1, #0
        beq rpoll               ; poll until something needs to be read

        ldrb r0, [r2]           ; read receiver buffer

        ldmfd sp!, {r1, r2, lr}
        bx lr

output_character
        stmfd sp!, {r1, r2, lr}

        ldr r2, =0xe000c000     ; UART0 base address

tpoll   ldrb r1, [r2, #u0lsr]   ; load status register
        and r1, r1, #0x20       ; test THRE
        cmp r1, #0
        beq tpoll               ; poll until ready to write

        strb r0, [r2]           ; write to UART register

        ldmfd sp!, {r1, r2, lr}
        bx lr

        end
