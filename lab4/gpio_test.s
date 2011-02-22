    area    gpio, code, readwrite   
    export lab4

    extern uart_init
    extern output_character
    extern read_character
    extern output_string
    extern read_string
    extern display_digit
    extern read_push_btns
    extern leds
    extern rgb_leds

piodata equ 0x8         ; Offset to parallel I/O data register
pinsel0 equ 0xe002c000
pinsel1 equ 0x4         ; offset from pinsel0
iobase equ 0xe0028000
                        ; io0pin has no offset
io0set equ 0x4
io0dir equ 0x8
io0clr equ 0xc
io1pin equ 0x10
io1set equ 0x14
io1dir equ 0x18
io1clr equ 0x1c

prompt  = "Welcome to lab #4 ",0    ; Text to be sent to PuTTy
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
        align

; lab4
; parameters: none
; returns: none
;
; First, allow user to hit all four momentary push buttons one at a time
; (simultaneous multiple buttons ignored). Illuminate LED next to push
; button being pushed. After all four have been pushed, enter next mode.
;
; Allow users to enter hex into PuTTY, and display digits on 7-segment
; display. Upon hitting [Qq], exit. Allowable inputs: [0-9a-zA-Z]. Turn
; off 7-segment display on invalid.
lab4
        stmfd sp!,{lr}  ; Store register lr on stack

        ; Mode 1

        ; setup gpio, makes sure ports 0.7-0.13 are for gpio by zeroing them.
        ldr r0, =pinsel0
        ldr r1, [r0]
        bic r1, r1, #0xff00000
        bic r1, r1, #0xfc000
        str r1, [r0]

        ; setup direction
        ; P1.16-P1.19, output, LEDs
        ; P1.20-P1.23, input, buttons
        ldr r0, =iobase
        add r0, r0, #io1dir
        ldr r1, [r0]
        orr r1, r1, #f0000
        bic r1, r1, #f00000
        str r1, [r0]

        ; Mode 2

        ; setup uart
        bl uart_init

        ldmfd sp!, {lr} ; Restore register lr from stack    
        bx lr
    
        end
