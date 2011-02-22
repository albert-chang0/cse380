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

prompt  = "Welcome to GPIO Test",10,13,\
          "Please push the buttons",0    ; Text to be sent to PuTTy
uprompt = 10,13,"Now use PuTTY and watch it display on 7-segment display.",10,13,0
vprompt = "Enter numbers and letters.",10,13,0
eprompt = "Error. ",0
exitmsg = 10,13,"Bye!",10,13,0
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
; display. Upon hitting [Qq], exit. Allowable inputs: [0-9a-fA-F]. Turn
; off 7-segment display on invalid.
lab4
        stmfd sp!,{lr}  ; Store register lr on stack

        ; Mode 1
        ; r1 - button counter
        mov r1, #0

        ; nice display
        bl uart_init
        ldr r0, =prompt
        bl output_string

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
        orr r1, r1, #0xf0000
        bic r1, r1, #0xf00000
        str r1, [r0]

        ; indicate we are waiting for user input
        ; green light
btnlp   mov r0, #0x400
        bl rgb_leds

        bl read_push_btns
        bl leds

        ; 0th bit indicates first button
        cmp r0, #0x0
        orr r1, r1, #1

        ; 1st bit indicates second button
        cmp r0, #0x0
        orr r1, r1, #2

        ; 2nd bit indicates third button
        cmp r0, #0x0
        orr r1, r1, #4

        ; 3rd bit indicates fourth button
        cmp r0, #0x0
        orr r1, r1, #8
        
        ; indicate user has pushed a button
        ; blue light
        mov r0, #0x30
        bl rgb_leds

        cmp r1, #0xf
        blt btnlp

        ; Mode 2

        ; make sure uart is ready
        ;bl uart_init

        ; indicate UART is running
        ; white light
        mov r0, #0x400
        add r0, r0, #0x3c
        bl rgb_leds

        ldr r0, =uprompt
        bl output_string
remind  ldr r0, =vprompt
        bl output_string

        bl read_character

        ; limit to [0-9a-fA-F]

        mov r1, #0
        ; 0-9
        cmp r0, #48
        addge r1, r1, #1
        cmp r0, #57
        addle r1, r1, #1
        cmp r1, #2
        b valid

        ; A-F
        mov r1, #0
        cmp r0, #65
        addge r1, r1, #1
        cmp r0, #70
        addle r1, r1, #1
        cmp r1, #2
        b valid

        ; a-f
        mov r1, #0
        cmp r0, #97
        addge r1, r1, #1
        cmp r0, #102
        addle r1, r1, #1
        cmp r1, #2
        b valid

        ; Q|q
        cmp r0, #81
        b exit
        cmp r0, #113
        b exit

        ldr r0, =eprompt
        bl output_string
        mov r0, #0
        bl display_digit
        b remind

valid   bl output_character
        mov r1, r0
        mov r0, #13
        bl output_character
        mov r0, r1
        bl display_digits

exit    ldr r0, =exitmsg
        bl output_string

        ; indicate user has quit the program
        ; red light
        mov r0, #0xc
        bl rgb_leds

        ldmfd sp!, {lr} ; Restore register lr from stack    
        bx lr

        end
