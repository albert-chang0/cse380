    area    serial, code, readwrite 
    export lab3
    
pinsel0 equ 0xe002c000  ; UART0 pin select
u0base equ 0xe000c000   ; UART0 base address
u0lsr equ 0x14          ; UART0 line status register
u0lcr equ 0xc           ; UART0 line control register
u0dlm equ 0x4           ; UART0 divisor latch MSB register
                        ; UART0 divisor latch LSB register has no offset

prompt = "Enter a number:  ",0          
        align

lab3
        stmfd sp!,{lr}  ; Store register lr on stack

        bl uart_init

        ldmfd sp!, {lr} ; Restore register lr from stack    
        bx lr

; uart_init
; parameters: none
; returns: none
;
; Enables and configures the UART we are going to use (UART0).
; Basically a translation of the function serial_init() in mod_ui_wrapper.c.
uart_init
        stmfd sp!, {r0, r1, lr}

        ldr r1, =pinsel0

        ; enable UART0
        ldr r0, [r1]
        bic r0, r0, #0xf
        orr r0, r0, #0x5
        str r0, [r1]

        ldr r1, =u0base

        ; configurations:
        ; 8-bit word length
        ; 1 stop bit
        ; no parity
        ; disable break control
        ; enable latch access
        mov r0, #0x83
        strb r0, [r1, #u0lcr]

        ; 9600 baud rate:
        mov r0, #0x78
        strb r0, [r1]
        mov r0, #0
        strb r0, [r1, #u0dlm]

        ; disable latch access
        mov r0, #3
        strb r0, [r1, #u0lcr]

        ldmfd sp!, {r0, r1, lr}
        bx lr

; output_character
; parameters:
;     r0 - character to output to UART
; returns: none
;
; Taken from the first part of lab3, this accepts a parameter from register
; r0, and outputs it to UART.
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

; read_character
; parameters: none
; returns:
;     r0 - character read in from UART
;
; Taken from the first part of lab3, this reads from UART and returns it in
; register r0.
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

; output_string
; parameters:
;     r0 - base address of string to be printed
; returns: none
;
; Displays a null terminated string, which the base address is passed in
; through register r0, to UART.
output_string
        stmfd sp!, {lr}


        ldmfd sp!, {lr}
        bx lr

; read_string
; parameters: none
; returns
;     r0 - base address of the string being stored
;
; Reads in a string from UART and stores the base address in register r0.
read_string
        stmfd sp!, {lr}


        ldmfd sp!, {lr}
        bx lr

; mod
; parameters:
;     r0 - divisor
;     r1 - dividened
; returns:
;     r0 - modulo of r0 and r1 (r1 % r0)
;
; Performs a modulo (remainder of a divide function) on the parameters
; passed through registers r0 and r1. The function should follow:
; r1 modulo r0 (r1 % r0)
; The majority of the function is taken from lab 2's division subroutine.
mod
        stmfd sp!, {r0-r4, lr}

        ; r0 - divisor
        ; r1 - dividend
        ; r2 - quotient
        ; r3 - remainder
        ; r4 - counter
        mov r2, #0 ; initialize quotient to 0
        mov r3, r1 ; initialize remainder to dividend
        mov r4, #0x10 ; initialize counter to 16
        mov r0, r0, lsl #0x10 ; logical left shift divisor 16 places
cloop   sub r3, r3, r0 ; remainder = remainder - divisor; cloop is the counter loop
        cmp r3, #0 ; remainder < 0
        blt rless
        mov r2, r2, lsl #1 ; left shift quotient
        add r2, r2, #1 ; lsb = 1
shftd   mov r0, r0, lsr #1 ; right shift divisor, msb = 0

        cmp r4, #0 ; counter > 0
        ble exit   ; counter <= 0 instead reduces number of branching instructions
        sub r4, r4, #1 ; decrement counter
        b cloop

exit    mov r0, r3 ; return remainder instead of quotient

        ldmfd r13!, {r0-r12, r14}
        bx lr      ; Return to the C program    

rless   add r3, r3, r0 ; remainder = remainder + divisor
        mov r2, r2, lsl #1 ; left shift quotient, lsb = 0
        b shftd

        end
