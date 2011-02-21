    area library, code, readwrite
    export uart_init
    export output_character
    export read_character
    export output_string
    export read_string
    export display_digit
    export read_push_btns
    export leds
    export rgb_leds

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

; insert read_string here when finished

; insert output_string here when finished

; display_digit
; parameters:
; returns:
;
; 
display_digit
        stmfd sp!, {lr}


        ldmfd sp!, {lr}
        bx lr

; read_push_btns
; parameters:
; returns:
;
;
read_push_btns
        stmfd sp!, {lr}


        ldmfd sp!, {lr}
        bx lr

; leds
; parameters:
; returns: 
;
; 
leds
        stmfd sp!, {lr}


        ldmfd sp!, {lr}
        bx lr

; rgb_leds
; parameters:
; returns:
;
; 
rgb_leds
        stmfd sp!, {lr}


        ldmfd sp!, {lr}
        bx lr
