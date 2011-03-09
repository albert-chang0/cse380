    area library, code, readwrite
    export uart_init
    export output_character
    export read_character
    export output_string
    export read_string
    export display_digit
    export read_push_btns
    export leds
    export rgb_led

pinsel0 equ 0xe002c000      ; UART0 pin select
u0base equ 0xe000c000       ; UART0 base address
u0lsr equ 0x14              ; UART0 line status register
u0lcr equ 0xc               ; UART0 line control register
u0dlm equ 0x4               ; UART0 divisor latch MSB register
u0dll equ 0x0               ; UART0 divisor latch LSB register has no offset
iobase equ 0xe0028000
io0clr equ 0xc
io0set equ 0x4
io1pin equ 0x10
io1clr equ 0x1c
io1set equ 0x14
digits_set  dcd 0x00001F80  ; 0
            dcd 0x00000300  ; 1 
            dcd 0x00002d80  ; 2
            dcd 0x00002780  ; 3
            dcd 0x00003300  ; 4
            dcd 0x00003680  ; 5
            dcd 0x00003e80  ; 6
            dcd 0x00000380  ; 7
            dcd 0x00003f80  ; 8
            dcd 0x00003780  ; 9
            dcd 0x00003b80  ; A
            dcd 0x00003e00  ; b
            dcd 0x00001c80  ; C
            dcd 0x00002f00  ; d
            dcd 0x00003c80  ; E
            dcd 0x00003880  ; F

; uart_init
; parameters: none
; returns: none
;
; Enables and configures the UART we are going to use (UART0).
; Basically a translation of the function serial_init() in mod_ui_wrapper.c.
uart_init
        stmfd sp!, {r1, lr}

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
        strb r0, [r1, #u0dll]
        mov r0, #0
        strb r0, [r1, #u0dlm]

        ; disable latch access
        mov r0, #3
        strb r0, [r1, #u0lcr]

        ldmfd sp!, {r1, lr}
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
        tst r1, #0x20           ; test THRE
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
        tst r1, #1              ; test ROR
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
        stmfd sp!, {r1, lr}

        mov r1, r0

soloop  ldrb r0, [r1], #1
        cmp r0, #0
        blne output_character
        bne soloop

        ldmfd sp!, {r1, lr}
        bx lr

; read_string
; parameters:
;    r0 - base address of string
; returns: none
;
; Reads in a string from UART and stores the base address in register r0.
read_string
        stmfd sp!, {r1, r2, lr}

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

        ldmfd sp!, {r1, r2, lr}
        bx lr

; display_digit
; parameters:
;     r0 - digit to be displayed
; returns: none
; 
; Displays the digit given in register r0 to the 7-segment digital display.
display_digit
        stmfd sp!, {r1, r2, lr}

        ; r1 - lights for 7-seg
        ; r2 - working address

        ; get value to display 8
        ldr r2, =digits_set
        ldr r1, [r2, #32]

        ; clear previous display
        ldr r2, =iobase
        str r1, [r2, #io0clr]

        ; if -1 is sent, clear and exit
        cmp r0, #-1
        ldmeqfd sp!, {r1, r2, lr}
        bxeq lr

        ; translate digit to 7-seg display light-up
        ldr r2, =digits_set
        ldr r1, [r2, r0, lsl #2]

        ; show on 7-seg display
        ldr r2, =iobase
        str r1, [r2, #io0set]

        ldmfd sp!, {r1, r2, lr}
        bx lr

; read_push_btns
; parameters: none
; returns:
;     r0 - button value
;
; Read momentary push button and returns its value in register r0.
; push buttons send 1 off, 0 on
; return as 1 on, 0 off
read_push_btns
        stmfd sp!, {r1, lr}

        ; load base address
        ldr r1, =iobase
        ldr r0, [r1, #io1pin]   ; loading the value from io1pin to r0
        and r0, r0, #0xf00000   ; isolate bits 20:23
        mov r0, r0, lsr #20

        ; flip bits so 1s become 0s, and 0s become 1s
        eor r0, r0, #0xf

        ; blink corresponding LED
        bl leds

        ldmfd sp!, {r1, lr}
        bx lr

; leds
; parameters:
;     r0 - pattern of leds
; returns: none
;
; Illuminates the pattern of LEDs passed into register r0.
; 0x1 - LED1
; 0x2 - LED2
; 0x4 - LED3
; 0x8 - LED4
leds
        stmfd sp!, {r1, r2, lr}

        ; r1 - working address
        ; r2 - scratchpad

        ; clears all LEDs
        ldr r1, =iobase
        mov r2, #0xf0000
        str r2, [r1, #io1set]

        ; turn on LED
        mov r2, r0, lsl #0x10
        str r2, [r1, #io1clr]

        ldmfd sp!, {r1, r2, lr}
        bx lr

; rgb_led
; parameters:
;     r0 - color
; returns: none
;
; lights up the colored LED passed into register r0.
rgb_led
        stmfd sp!, {r1, r2, lr}

        ldr r1, =iobase

        ; turn off previous lights
        mov r2, #0x260000
        str r2, [r1, #io0set]

        mov r2, r0, lsl #0x10
        str r2, [r1, #io0clr]

        ldmfd sp!, {r1, r2, lr}
        bx lr

        end
