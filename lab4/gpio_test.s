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
    extern rgb_led

piodata equ 0x8         ; Offset to parallel I/O data register
pinsel0 equ 0xe002c000
pinsel1 equ 0x4         ; offset from pinsel0
iobase equ 0xe0028000
                        ; io0pin has no offset
io0dir equ 0x8
io1dir equ 0x18

prompt  = "Welcome to GPIO Test!",10,13,\
          "Please push the buttons.",0    ; Text to be sent to PuTTy
uprompt = 10,13,"Now use PuTTY and watch it display on 7-segment display.",10,13,0
vprompt = "Enter numbers and letters.",10,13,0
eprompt = "Error. ",0
exitmsg = 10,13,"Bye!",10,13,0
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
        ; P0.17, P0.18, P0.20, output RGB LED
        ; P0.7-P0.13, output 7-segment
        ldr r0, =iobase
        ldr r1, [r0, #io1dir]
        orr r1, r1, #0xf0000
        bic r1, r1, #0xf00000
        str r1, [r0, #io1dir]
        ldr r1, [r0, #io0dir]
        orr r1, r1, #0x260000
        orr r1, r1, #0x3f80
        str r1, [r0, #io0dir]

        ; turn off LEDs
        mov r0, #0
        bl leds
        bl rgb_led

        ; test code
        mov r0, #0
        bl display_digit
        ; end test

        mov r1, #0

        ; indicate we are waiting for user input
        ; green light
btnpl   mov r0, #0x20
        bl rgb_led

        bl read_push_btns

        ; 0th bit indicates first button
        ; only stores when one button is pushed
        cmp r0, #2_1
        orreq r1, r1, #2_1

        ; 1st bit indicates second button
        ; only store when one button is pushed
        cmp r0, #2_10
        orreq r1, r1, #2_10

        ; 2nd bit indicates third button
        ; only store when one button is pushed
        cmp r0, #2_100
        orreq r1, r1, #2_100

        ; 3rd bit indicates fourth button
        ; only store when one button is pushed
        cmp r0, #2_1000
        orreq r1, r1, #2_1000
        
        ; indicate user has pushed a button
        ; blue light
        mov r0, #0x4
        bl rgb_led

        cmp r1, #0xf
        blt btnpl

        ; Mode 2

        ; make sure uart is ready
        ;bl uart_init

        ; indicate UART is running
        ; white light
        mov r0, #0x26
        bl rgb_led

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
        ; convert from string to hexadecimal
        bl display_digit

exit    ldr r0, =exitmsg
        bl output_string

        ; indicate user has quit the program
        ; red light
        mov r0, #0x2
        bl rgb_led

        ldmfd sp!, {lr} ; Restore register lr from stack    
        bx lr

        end
