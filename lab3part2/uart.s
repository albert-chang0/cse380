    area    serial, code, readwrite 
    export lab3
    
u0lsr equ 0x14          ; UART0 Line Status Register

        ; You'll want to define more constants to make your code easier 
        ; to read and debug
       
        ; Memory allocated for user-entered strings

prompt = "Enter a number:  ",0          

        ; Additional strings may be defined here

        align


lab3
        stmfd sp!,{lr}  ; Store register lr on stack

            ; Your code is placed here

        ldmfd sp!, {lr} ; Restore register lr from stack    
        bx lr

uart
        stmfd sp!, {r1-r12, lr}

        ldmfd sp!, {r1-r12, lr}
        bx lr

read_string
        stmfd sp!, {r1-r12, lr}

        ldmfd sp!, {r1-r12, lr}
        bx lr

output_string
        stmfd sp!, {r1-r12, lr}

        ldmfd sp!, {r1-r12, lr}
        bx lr

mod
        stfmd sp!, {r1-r12, lr}

        ldmfd sp!, {r1-r12, lr}
        bx lr

        end
