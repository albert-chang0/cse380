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

pinsel0 equ 0xe002c000      ; UART0 pin select
u0base equ 0xe000c000       ; UART0 base address
u0lsr equ 0x14              ; UART0 line status register
u0lcr equ 0xc               ; UART0 line control register
u0dlm equ 0x4               ; UART0 divisor latch MSB register
                            ; UART0 divisor latch LSB register has no offset
; uart_init
; parameters: none
; returns: none
;
; Enables and configures the UART we are going to use (UART0).
; Basically a translation of the function serial_init() in mod_ui_wrapper.c.
uart_init
        stmfd sp!, {r1-r12, lr}

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

        ldmfd sp!, {r1-r12, lr}
        bx lr

; output_character
; parameters:
;     r0 - character to output to UART
; returns: none
;
; Taken from the first part of lab3, this accepts a parameter from register
; r0, and outputs it to UART.
output_character
        stmfd sp!, {r1-r12, lr}

        ldr r2, =u0base         ; UART0 base address

tpoll   ldrb r1, [r2, #u0lsr]   ; load status register
        and r1, r1, #0x20       ; test THRE
        cmp r1, #0
        beq tpoll               ; poll until ready to write

        strb r0, [r2]           ; write to UART register

        ldmfd sp!, {r1-r12, lr}
        bx lr

; read_character
; parameters: none
; returns:
;     r0 - character read in from UART
;
; Taken from the first part of lab3, this reads from UART and returns it in
; register r0.
read_character
        stmfd sp!, {r1-r12, lr}

        ldr r2, =u0base         ; UART0 base address

rpoll   ldrb r1, [r2, #u0lsr]   ; load status register
        and r1, r1, #1          ; test RDR
        cmp r1, #0
        beq rpoll               ; poll until something needs to be read

        ldrb r0, [r2]           ; read receiver buffer

        ldmfd sp!, {r1-r12, lr}
        bx lr

; output_string
; parameters:
;     r0 - base address of string to be printed
; returns: none
;
; Displays a null terminated string, which the base address is passed in
; through register r0, to UART.
output_string
        stmfd sp!, {r1-r12, lr}

        mov r1, r0

soloop  ldrb r0, [r1], #1
        cmp r0, #0
        blne output_character
        bne soloop

        ldmfd sp!, {r1-r12, lr}
        bx lr

; read_string
; parameters:
;    r0 - base address of string
; returns: none
;
; Reads in a string from UART and stores the base address in register r0.
read_string
        stmfd sp!, {r1-r12, lr}

        mov r1, r0

read    bl read_character
        bl output_character     ; give instant feedback
        ; output non-printable characters, but don't store them
        mov r2, #0
        cmp r0, #32
        addge r2, #1
        cmp r0, #126
        addle r2, #1
        cmp r2, #2
        strbeq r0, [r1], #1
        cmp r0, #0xd            ; returns on carriage return
        bne read

        ; store null character
        mov r0, #0
        strb r0, [r1]

        mov r0, #0xa
        bl output_character
        mov r0, #0xd
        bl output_character

        mov r1, r0

        ldmfd sp!, {r1-r12, lr}
        bx lr

; display_digit
; parameters:
;     r0 - digit to be displayed
; returns: none
; 
; Displays the digit given in register r0 to the 7-segment digital display.
display_digit
        stmfd sp!, {r1-r12, lr}


        ldmfd sp!, {r1-r12, lr}
        bx lr

; read_push_btns
; parameters: none
; returns:
;     r0 - button value
;
; Read momentary push button and returns its value in register r0.
read_push_btns
        stmfd sp!, {r1-r12, lr}


        ldmfd sp!, {r1-r12, lr}
        bx lr

; leds
; parameters:
;     r0 - pattern of leds
; returns: none
;
; Illuminates the pattern of LEDs passed into register r0.
leds
        stmfd sp!, {r1-r12, lr}


        ldmfd sp!, {r1-r12, lr}
        bx lr

; rgb_leds
; parameters:
;     r0 - color
; returns: none
;
; lights up the colored LED passed into register r0.
; red:   0xc bits 0-3
; blue:  0x3 bits 4-7
; green: 0x4 bits 8-11
rgb_leds
        stmfd sp!, {r1-r12, lr}

        ldr r1, =pinsel0
        ldr r2, [r1]

        bic r2, r2, #f00
        bic r2, r2, #ff
        orr r2, r2, r0

        str r2, [r1]

        ldmfd sp!, {r1-r12, lr}
        bx lr

        end
