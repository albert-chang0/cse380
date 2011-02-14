    area    serial, code, readwrite 
    export lab3
    
pinsel0 equ 0xe002c000  ; UART0 pin select
u0base equ 0xe000c000   ; UART0 base address
u0lsr equ 0x14          ; UART0 line status register

lab3
        stmfd sp!,{lr}  ; Store register lr on stack

        ; enable UART0
        ldr r2, =pinsel0
        ldr r1, [r2]
        bic r1, r1, #0xf
        orr r1, r1, #0x5
        str r1, [r2]

        bl read_character
        bl output_character

        ldmfd sp!, {lr} ; Restore register lr from stack    
        bx lr

read_character
        stmfd sp!, {r1, r2, lr}

        ldr r2, =u0base         ; UART0 base address

rpoll   ldrb r1, [r2, #u0lsr]   ; load status register
        and r1, r1, #1          ; test RDR
        cmp r1, #0
        beq rpoll               ; poll until something needs to be read

        ldrb r0, [r2]           ; read receiver buffer

        ldmfd sp!, {r1, r2, lr}
        bx lr

output_character
        stmfd sp!, {r1, r2, lr}

        ldr r2, =u0base         ; UART0 base address

tpoll   ldrb r1, [r2, #u0lsr]   ; load status register
        and r1, r1, #0x20       ; test THRE
        cmp r1, #0
        beq tpoll               ; poll until ready to write

        strb r0, [r2]           ; write to UART register

        ldmfd sp!, {r1, r2, lr}
        bx lr

        end
