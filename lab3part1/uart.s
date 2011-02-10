    area    serial, code, readwrite 
    export lab3
    
    u0lsr equ 0x14          ; UART0 Line Status Register

    ; You'll want to define more constants to make your code easier 
    ; to read and debug


lab3
        stmfd sp!,{lr}  ; Store register lr on stack

        ; bl read_character
        ; test code
        mov r0, #65
        bl output_character

        ldmfd sp!, {lr} ; Restore register lr from stack    
        bx lr

read_character
        stmfd sp!, {r1-r12, lr}

        ldmfd sp!, {r1-r12, lr}
        bx lr

output_character
        stmfd sp!, {r1-r12, lr}

        ldmfd sp!, {r1-r12, lr}
        bx lr

        end
