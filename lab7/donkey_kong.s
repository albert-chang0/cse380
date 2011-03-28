    area donkey_kong, code, readwrite 

    export game 
    export FIQ_Handler

    extern mod
    extern uart_init
    extern output_character
    extern read_character
    extern output_string
    extern display_digit
    extern leds

pinsel0 equ 0xe002c000      ; pin select
rtcbase equ 0xe0024000      ; rtc base address
ccr equ 0x8                 ; clock counter register
ctc equ 0x4
u0base equ 0xe000c000       ; UART0 base address
u0ier equ 0x4               ; UART0 interrupt enable register
u0iir equ 0x8               ; UART0 interrupt identification register
iobase equ 0xe0028000
io0dir equ 0x8
io1dir equ 0x18
extint equ 0xe01fc140       ; external interrupt flag
extmode equ 0x8             ; external interrupt mode control
timer0 equ 0xe0004000
timer1 equ 0xe0008000
tc equ 0x8
mcr equ 0x14
pr equ 0xc
tir equ 0x0
tcr equ 0x4
mr1 equ 0x1c
vicbaseaddr equ 0xfffff000  ; vic base address
vicintenable equ 0x10       ; interrupt enable
vicintselect equ 0xc        ; select fiq or irq
vicintenclr equ 0x14        ; vic interrupt clear register

map = "   SCORE:00000  ",10,13,\
      "+--------------+",10,13,\
      "|              |",10,13,\
      "|   !          |",10,13,\
      "|   ===H       |",10,13,\
      "|      H       |",10,13,\
      "|&     H       |",10,13,\
      "|-------#---H  |",10,13,\
      "|           H  |",10,13,\
      "|           H  |",10,13,\
      "|  ==H=========|",10,13,\
      "|    H         |",10,13,\
      "|    H         |",10,13,\
      "|-#--------H-  |",10,13,\
      "|          H   |",10,13,\
      "|          H   |",10,13,\
      "|  H===========|",10,13,\
      "|  H           |",10,13,\
      "|  H           |",10,13,\
      "|-----------H  |",10,13,\
      "|           H  |",10,13,\
      "|           H  |",10,13,\
      "+==============+",0

pause_swap = "|              |",10,13,\
             "| P A U S E D  |",10,13,\
             "|              |",10,13

game_over_swap = "|              |",10,13,\
                 "|   G A M E    |",10,13,\
                 "|    O V E R   |",10,13,\
                 "|              |",10,13
        align

mario_pos dcd 0x8151
barrels dcd 0,0,0,0,0
score dcw 0
lvl_lives dcb 0x1f
        align

; game
; parameters: none
; returns: none
;
; Allows the user to play mario. Mario must reach the princess for each level.
; 5*lvl points are awarded for jumping over a barrel, and 100*lvl points are
; awarded upon completing each level. Every 1000 points earns the user another
; life.
game
        stmfd sp!,{lr}  ; Store register lr on stack

        ; start clock
        ldr r3, =rtcbase
        mov r0, #0x11
        str r0, [r3, #ccr]

        bl uart_init
        bl interrupt_init

        ldr r0, =timer0
        ldr r1, =0x2d000
        str r1, [r0, #pr]       ; set increment to ~0.01s
        mov r1, #26
        str r1, [r0, #mr1]      ; set initial speed to ~4char/s (+0.01s)

        ; set initial barrel ejection frequency to ~1char/8s
        ldr r0, =timer1
        ldr r1, =0x708000
        str r1, [r0, #pr]       ; set increment to ~0.4s
        mov r1, #21             ; set initial frequency to ~1barrel/8s (+0.4s)
        str r1, [r0, #mr1]

        ; setup display, makes sure ports 0.7-0.13 are for gpio by zeroing them.
        ; setup push button
        ldr r0, =pinsel0
        ldr r1, [r0]
        bic r1, r1, #0xff00000
        bic r1, r1, #0xfc000
        orr r1, r1, #0x20000000
        bic r1, r1, #0x10000000
        str r1, [r0]

        ; setup direction
        ; P1.16-P1.19, output, LEDs
        ; P0.7-P0.13, output 7-segment
        ldr r0, =iobase
        ldr r1, [r0, #io1dir]
        orr r1, r1, #0xf0000
        str r1, [r0, #io1dir]
        ldr r1, [r0, #io0dir]
        orr r1, r1, #0x260000
        orr r1, r1, #0x3f80
        str r1, [r0, #io0dir]

        ; r0 - level/lives
        ; r1 - lvl_lives address
        ; r2 - lvl_lives info
        ; r3 - timer0 address
        ; r4 - timer1 address
        ; r5 - scratchpad
        ; r6 - scratchpad

        ldr r1, =lvl_lives
        ldr r3, =timer0
        ldr r4, =timer1

        ; show amount of lives
        mov r0, #0xf
        bl leds

        mov r0, #1

start   bl display_digit

        ; delete all barrels
        ldr r5, =barrels
        mov r6, #0
        str r6, [r5]
        str r6, [r5, #1]
        str r6, [r5, #2]
        str r6, [r5, #3]
        str r6, [r5, #4]

        bl mk_barrel
        bl set_mario

        mov r6, r0

        ; clear prompt
        mov r0, #0xc
        bl output_character

        ; initial display
        ldr r0, =map
        bl output_string

        ; reset timers
        mov r5, #2
        str r5, [r3, #tcr]
        str r5, [r3, #tcr]

        ; decrement match registers
        ldr r5, [r3, #mr1]          ; faster barrels
        sub r5, r5, #1
        str r5, [r3, #mr1]
        ldr r5, [r4, #mr1]          ; more frequent barrels
        sub r5, r5, #1
        str r5, [r3, #mr1]

        ; start timers
        mov r5, #1
        str r5, [r3, #tcr]
        str r5, [r3, #tcr]

        ldrb r5, [r1]
        bic r5, r5, #0x1f0

        mov r0, r6

iloop   ldrb r2, [r1]
        cmp r0, r2, lsr #4          ; detect new level
        andne r6, r2, #0xf0
        movne r0, r6, lsr #4
        bne start
        bic r6, r2, #0x1f0
        cmp r6, r5                  ; detect loss in life
        blt start
        tst r2, #0xf0               ; finished all levels, game over
        tstne r2, #0xf              ; out of lives, game over
        bne iloop

        ; game over
        ldr r0, =map
        add r0, r0, #144
        ldr r1, =game_over_swap
        bl ln_swap
        add r0, r0, #18
        add r1, r1, #18
        bl ln_swap
        add r0, r0, #18
        add r1, r1, #18
        bl ln_swap
        add r0, r0, #18
        add r1, r1, #18
        bl ln_swap

        ldmfd sp!, {lr} ; Restore register lr from stack    
        bx lr       

; interrupt_init
; parameters: none
; returns: none
;
; Sets up the follow interrupts {and their functions}:
;     - TIMER: updates barrels
;     - UART: move Mario
;     - EINT: push button to toggle pause
interrupt_init
        stmfd sp!, {r0, r1, lr}

        ; classify sources as IRQ or FIQ
        ldr r0, =vicbaseaddr
        ldr r1, [r0, #vicintselect]
        orr r1, r1, #0x70               ; UART0, TIMER0, and TIMER1
        orr r1, r1, #0x8000             ; EINT1
        str r1, [r0, #vicintselect]

        ; enable interrupts
        ldr r1, [r0, #vicintenable]
        orr r1, r1, #0x70               ; UART0, TIMER0, and TIMER1
        orr r1, r1, #0x8000             ; EINT1
        str r1, [r0, #vicintenable]

        ; UART0 interrupt on RX
        ldr r0, =u0base
        ldr r1, [r0, #u0ier]
        orr r1, r1, #1
        str r1, [r0, #u0ier]

        ; TIMER0 interrupt
        ldr r0, =timer0
        ldr r1, [r0, #mcr]
        orr r1, r1, #0x18
        str r1, [r0, #mcr]

        ; TIMER1 interrupt
        ldr r0, =timer1
        ldr r1, [r0, #mcr]
        orr r1, r1, #0x18
        str r1, [r0, #mcr]

        ; EINT1 setup for edge sensitive
        ldr r0, =extint
        ldr r1, [r0, #extmode]
        orr r1, r1, #2                  ; EINT1 = Edge Sensitive
        str r1, [r0, #extmode]

        ; enable FIQs, disable IRQs
        mrs r0, cpsr
        bic r0, r0, #0x40
        orr r0, r0, #0x80
        msr cpsr_c, r0

        ldmfd sp!, {r0, r1, lr}
        bx lr

; FIQ_Handler
; parameters: none
; returns: none
;
; Fast interrupt handler.
; Timer interrupt:
;     Updates barrel position/gravity, adds a new barrel if necessary
; UART interrupt:
;     Moves Mario
; External interrupt
;     Disables UART and timer
FIQ_Handler
        stmfd sp!, {r0-r12, lr}

        ; stop timers
        ldr r0, =timer0
        mov r1, #0
        str r1, [r0, #tcr]
        ldr r0, =timer1
        str r1, [r0, #tcr]

        ; timer0 matched
        ldr r0, =timer0
        ldr r1, [r0, #tir]
        tst r1, #2
        beq t1ir
        ; reset interrupt
        orr r1, r1, #2
        str r1, [r0, #tir]

        bl fall_mario
        bl mv_barrel

        ; clear prompt
        mov r0, #0xc
        bl output_character

        ldr r0, =map
        bl output_string

        ; start timers
        ldr r0, =timer0
        mov r1, #1
        str r1, [r0, #tcr]
        ldr r0, =timer1
        str r1, [r0, #tcr]

        ldmfd sp!, {r0-r12, lr}         ; exit FIQ
        subs pc, lr, #4

        ; timer1 matched
t1ir    ldr r0, =timer1
        ldr r1, [r0, #tir]
        tst r1, #2
        beq uart0
        ; reset interrupt
        orr r1, r1, #2
        str r1, [r0, #tir]

        bl mk_barrel

        ; clear prompt
        mov r0, #0xc
        bl output_character

        ldr r0, =map
        bl output_string

        ; start timers
        ldr r0, =timer0
        mov r1, #1
        str r1, [r0, #tcr]
        ldr r0, =timer1
        str r1, [r0, #tcr]

        ldmfd sp!, {r0-r12, lr}
        subs pc, lr, #4                 ; exit FIQ

        ; uart0 input?
uart0   ldr r0, =u0base
        ldr r1, [r0, #u0iir]
        tst r1, #1
        bne eint1

        bl mv_mario

        ; clear prompt
        mov r0, #0xc
        bl output_character

        ldr r0, =map
        bl output_string

        ; start timers
FIQ_ext ldr r0, =timer0
        mov r1, #1
        str r1, [r0, #tcr]
        ldr r0, =timer1
        str r1, [r0, #tcr]

        ldmfd sp!, {r0-r12, lr}
        subs pc, lr, #4                 ; exit FIQ

        ; push button?
eint1   ldr r0, =extint
        ldr r1, [r0]
        tst r1, #2

        bne FIQ_ext                     ; no pending interrupts

        ; clear external interrupt
        orr r1, r1, #2
        str r1, [r0]

        bl pause_button

        ; clear prompt
        mov r0, #0xc
        bl output_character

        ldr r0, =map
        bl output_string

        ldmfd sp!, {r0-r12, lr}
        subs pc, lr, #4

; mv_barrel
; parameters: none
; returns: none
;
; Moves all the barrels on the map. Barrels are stored in memory. Information
; packed together in the following format:
;     0:3   x-position
;     4:8   y-position
;     9:10  direction
;    11:18  previous char
;
; Some memory could be saved if each barrel wasn't aligned since not all 32
; bits are not required to store information.
mv_barrel
        stmfd sp!, {r0-r8, lr}

        ; r1 - address of current working barrel
        ; r2 - barrel information
        ; r3 - parsed position
        ; r4 - environment
        ; r5 - character swap
        ; r6 - scratchpad0
        ; r7 - scratchpad1
        ; r8 - counter

        ldr r1, =barrels
        ldr r4, =map
        mov r8, #0

bcloop  ldr r2, [r1, r8, lsl #2]
        cmp r8, #5
        ldmeqfd sp!, {r0-r8, lr}
        bxeq lr
        cmp r2, #0
        addeq r8, r8, #1
        beq bcloop

        ; parse position
        ; 18y + x
        and r3, r2, #0x1f0          ; isolate y-position, and get 16y
        add r3, r3, r3, lsr #3      ; get 18y
        and r6, r2, #0xf            ; isolate x-position
        add r3, r3, r6              ; 18y + x

        ; get replaced character
        mov r5, r2, lsr #11
        strb r5, [r4, r3]           ; restore character
        bic r2, r2, #0xf800
        bic r2, r2, #0x70000

        ; contextualize
        add r7, r3, #18
        ldrb r6, [r4, r7]
        mov r7, #0
        cmp r6, #32
        orreq r7, r7, #2_1000       ; next line is ' '
        cmp r6, #72
        orreq r7, r7, #2_0100       ; next line is 'H'
        cmp r6, #35
        orreq r7, r7, #2_0001       ; next line is '#'
        cmp r5, #72
        orreq r7, r7, #2_0010       ; replacement is 'H'

        mov r0, #0
        ldr r6, =rtcbase
        tst r7, #2_0001             ; if it could fall, should it?
        ldrne r0, [r6, #ctc]
        andne r0, r0, #1
        teq r7, #2_0100
        ldreq r0, [r6, #ctc]
        andeq r0, r0, #1
        orr r7, r7, r0, lsl #3
        tst r7, #2_1000
        bne bfall                   ; nothing supporting, definitely falling
        teq r7, #2_0110
        beq bfall                   ; mid-fall down ladder, keep falling
        ldr r6, =379                ; barrel at the end of its path
        cmp r3, r6
        moveq r2, #0
        streq r2, [r1, r8, lsl #2]
        addeq r8, r8, #1
        beq bcloop
        tst r2, #0x400              ; if it had just fallen
        eorne r2, r2, #0x200        ; change direction
        bicne r2, r2, #0x400        ; clear falling flag
        tst r2, #0x200
        movne r6, #1
        mvneq r6, #0
        add r2, r2, r6
        add r3, r3, r6
        ldrb r5, [r4, r3]
        add r2, r2, r5, lsl #11     ; save replaced character
        mov r5, #64
        strb r5, [r4, r3]           ; move barrel

        str r2, [r1, r8, lsl #2]            ; update barrel

        ; collision detection goes here

        add r8, r8, #1
        b bcloop

bfall   orr r2, r2, #0x400          ; set falling flag
        add r2, r2, #0x10           ; update position
        ldrb r6, [r4, r3]
        add r2, r2, r6, lsl #11     ; save replaced character
        mov r6, #64
        add r3, r3, #18
        strb r6, [r4, r3]           ; move barrel

        str r2, [r1, r8, lsl #2]            ; update barrel

        ; collision detection goes here

        add r8, r8, #1
        b bcloop

; mk_barrel
; parameters: none
; returns: none
;
; Generates a new barrel.
mk_barrel
        stmfd sp!, {r0, r1, lr}

        ldr r0, =barrels
seek    ldr r1, [r0], #4            ; find first available space in RAM
        cmp r1, #0
        bne seek

        ; create barrel
        ldr r1, =0x10262
        str r1, [r0, #-4]

        ; draw barrel
        ldr r0, =map
        mov r1, #64
        strb r1, [r0, #110]

        ldmfd sp!, {r0, r1, lr}
        bx lr

; mv_mario
; parameters:
;     r0 - input
; returns: none
;
; Moves Mario according to the user input. Mario is stored in memory.
; Information is packed together in the following format:
;     0:3   x-position
;     4:8   y-position
;     9     controlled fall (jump)
;    10:17  previous char
;
; Some memory could be saved if there was no alignment since not all 32 bits
; are required to store information.
mv_mario
        stmfd sp!, {r0-r8, lr}
        
        ; r1 - address of mario's position
        ; r2 - mario's position
        ; r3 - parsed position
        ; r4 - environment
        ; r5 - character swap
        ; r6 - scratchpad0
        ; r7 - scratchpad1
        ; r8 - scratchpad2

        ldr r1, =mario_pos
        ldr r2, [r1]
        ldr r4, =map

        ; parse position
        ; 18y + x
        and r3, r2, #0x1f0          ; isolate y-position, and get 16y
        add r3, r3, r3, lsr #3      ; get 18y
        and r6, r2, #0xf            ; isolate x-position
        add r3, r3, r6              ; 18y + x

        ; check if it's falling
        add r6, r3, #18
        ldr r6, [r4, r6]
        cmp r6, #32                 ; nothing supporting Mario
        ldmeqfd sp!, {r1-r8, lr}    ; let timer interrupts handle falling mario
        bxeq lr

        tst r2, #0x200              ; mid-jump
        ldmnefd sp!, {r1-r8, lr}
        bxne lr

        ; get replaced character
        mov r5, r2, lsr #10

        ; contextualize
        mov r7, #0
        add r8, r3, #18
        ldrb r6, [r4, r8]
        cmp r5, #72
        orreq r7, r7, #2_0001       ; replacement is 'H'
        cmp r6, #72
        orreq r7, r7, #2_0010       ; next line is 'H'
        add r8, r3, #1
        ldrb r6, [r4, r8]
        cmp r6, #0x7c
        orreq r7, r7, #2_0100       ; next character is '|'
        sub r8, r3, #1
        ldrb r6, [r4, r8]
        cmp r6, #0x7c
        orreq r7, r7, #2_1000       ; previous character is '|'

        bl read_character

        ; r6 - delta parsed position
        ; r7 - delta x position
        ; r8 - delta y position

        cmp r0, #0x77
        beq up
        cmp r0, #0x61
        beq left
        cmp r0, #0x73
        beq down
        cmp r0, #0x64
        beq right
        cmp r0, #0x41
        beq jleft
        cmp r0, #0x44
        ldmnefd sp!, {r0-r8, lr}    ; invalid input, exit
        bxne lr

        ; jump right
jright  bic r8, r7, #0xc
        cmp r8, #0x3
        ldmeqfd sp!, {r0-r8, lr}
        bxeq lr
        tst r7, #0x4
        ldmnefd sp!, {r0-r8, lr}
        bxne lr

        ; set jump flag
        orr r2, r2, #0x200

        mov r6, #-17
        mov r7, #1
        mvn r8, #0

        b valid

        ; jump left
jleft   bic r8, r7, #0xc
        cmp r8, #0x3
        ldmeqfd sp!, {r0-r8, lr}    ; invalid move, exit
        bxeq lr
        tst r7, #0x8
        ldmnefd sp!, {r0-r8, lr}    ; invalid move, exit
        bxne lr

        ; set jump flag
        orr r2, r2, #0x200

        mov r6, #-19
        mvn r7, #0
        mvn r8, #0

        b valid

        ; move right
right   bic r8, r7, #0xc
        cmp r8, #0x3
        ldmeqfd sp!, {r0-r8, lr}
        bxeq lr
        tst r7, #0x4
        ldmnefd sp!, {r0-r8, lr}
        bxne lr

        mov r6, #1
        mov r7, #1
        mov r8, #0

        b valid

        ; move down
down    tst r7, #2
        ldmeqfd sp!, {r0-r8, lr}    ; invalid move, exit
        bxeq lr

        mov r6, #18
        mov r7, #0
        mov r8, #1

        b valid

        ; move left
left    bic r8, r7, #0xc
        cmp r8, #0x3
        ldmeqfd sp!, {r0-r8, lr}    ; invalid move, exit
        bxeq lr
        tst r7, #0x8
        ldmnefd sp!, {r0-r8, lr}    ; invalid move, exit
        bxne lr

        mvn r6, #0
        mvn r7, #0
        mov r8, #0

        b valid

        ; move up
up      tst r7, #1
        ldmeqfd sp!, {r0-r8, lr}
        bxeq lr

        mov r6, #-18
        mov r7, #0
        mvn r8, #0

valid   strb r5, [r4, r3]            ; restore character
        bic r2, r2, #0xf800
        bic r2, r2, #0x70000

        ; make the move
        add r3, r3, r6              ; parsed position
        add r2, r2, r7              ; x-position
        add r2, r2, r8, lsl #4      ; y-position

        ; save previous character
        ldrb r5, [r4, r3]
        orr r2, r2, r5, lsl #10

        str r2, [r1]                ; save mario's position

        ; update display
        mov r5, #36
        strb r5, [r4, r3]

        ; collision detection goes here

        ; potential points
        ldr r0, =lvl_lives
        ldrb r0, [r0]
        mov r0, r0, lsr #4          ; clear out lives data
        add r0, r0, lsl #2          ; 5 * lvl

        ; check if jumped over a barrel
        mov r6, #0
        tst r2, #0x200
        addne r3, r3, #18
        ldrneb r6, [r4, r3]
        cmp r6, #64
        bleq add_score

        ; check if reached princess
        cmp r3, #59
        ldmnefd sp!, {r0-r8, lr}    ; didn't reach
        bxne lr

        ; process new level
        ldr r0, =lvl_lives
        ldrb r1, [r0]
        mov r2, r1, lsr #4
        add r2, r1, #0x10           ; increment level
        strb r2, [r0]
        mov r0, r1, lsl #6
        add r0, r0, r1, lsl #5
        add r0, r0, r1, lsl #2      ; 100 * lvl
        bl add_score

        ldmfd sp!, {r0-r8, lr}
        bx lr

; pause_button
; parameters: none
; returns: none
;
; Toggles pause and pause display. Swaps whatever is in the map on lines 10-13
; with pause_swap. Implemented by disabling timer counter and UART0 RX line in
; pin selection. This preserves the timer and prevents filling of the receive
; buffer.
pause_button
        stmfd sp!, {r0, r1, lr}

        ; toggle timer counters
        ldr r0, =timer0
        ldr r1, [r0, #tcr]
        eor r1, r1, #1
        str r1, [r0, #tcr]
        ldr r1, =timer1
        str r1, [r0, #tcr]

        ; toggle uart receive
        ldr r0, =pinsel0
        ldr r1, [r0]
        eor r1, r1, #4
        str r1, [r0]

        ; toggle pause display
        ldr r0, =map
        add r0, r0, #180
        ldr r1, =pause_swap
        bl ln_swap
        add r0, r0, #18
        add r1, r1, #18
        bl ln_swap
        add r0, r0, #18
        add r1, r1, #18
        bl ln_swap

        ldmfd sp!, {r0, r1, lr}
        bx lr

; add_score
; parameters:
;     r0 - increment
; returns: none
;
; Performs all score handling. When score reaches 1000, add a new life.
; Also caps score to displayable digits.
add_score
        stmfd sp!, {r0-r2, lr}

        ldr r1, =score
        ldrh r2, [r1]

        ldr r3, =99999
        add r2, r2, r0
        cmp r3, r2
        movgt r2, r3
        strh r2, [r1]

        mov r1, r0
        ldr r2, =map
        ldr r3, [r2, #10]       ; for detecting 1000 point reach
        add r2, r2, #13

        ; convert binary integer to string of integers for printing
itoa    mov r0, #10
        bl mod                  ; isolate last number
        add r0, r0, #48         ; convert integer to ascii by adding 48
        strb r0, [r2], #-1      ; update display
        cmp r1, #0
        bne itoa

        ldr r1, =map
        ldr r2, [r1, #10]       ; for detecting 1000 point reach
        cmp r3, r2
        ldmeqfd sp!, {r0-r2, lr}

        ; 1000 points reached, gain a life
        ldr r0, =lvl_lives
        ldrb r1, [r0]
        and r2, r1, #0xf
        orr r1, r1, r2, lsr #1
        strb r1, [r0]

        ldmfd sp!, {r0-r2, lr}

; fall_mario
; parameters: none
; returns: none
;
; Makes mario fall
fall_mario
        stmfd sp!, {r1-r7, lr}

        ; r1 - address of mario's position
        ; r2 - mario's position
        ; r3 - parsed position
        ; r4 - environment
        ; r5 - character swap
        ; r6 - scratchpad0
        ; r7 - scratchpad1

        ldr r1, =mario_pos
        ldr r4, =map
        ldr r2, [r1]

        ; parse position
        ; 18y + x
        and r3, r2, #0x1f0          ; isolate y-position, and get 16y
        add r3, r3, r3, lsr #3      ; get 18y
        and r6, r2, #0xf            ; isolate x-position
        add r3, r3, r6              ; 18y + x

        tst r2, #0x200
        bne mfall                   ; fall because of jump

        add r6, r3, #18
        ldrb r6, [r4, r6]
        cmp r6, #32                 ; fall because there's no support
        cmpne r6, #64               ; barrels are not support characters
        ldmnefd sp!, {r1-r7, lr}
        bxne lr

        ; replaced character
mfall   mov r5, r2, lsr #10
        strb r5, [r4, r3]
        bic r2, r2, #0xf800
        bic r2, r2, #0x70000

        ; update positions
        add r3, r3, #18
        add r2, r2, #0x10

        ; save previous character
        ldrb r5, [r4, r3]
        orr r2, r2, r5, lsl #10

        ; update display
        mov r5, #36
        strb r5, [r4, r3]

        mov r7, #0

        ; landing
        add r6, r3, #18
        ldrb r6, [r4, r6]
        cmp r6, #32                 ; fall because there's no support
        cmpne r6, #64               ; barrels are not support characters
        orrne r7, r7, #0x1

        ; from a jump
        tst r2, #0x200
        orrne r7, r7, #0x10

        ; jumps should only last one fall
        bic r2, r2, #0x200

        str r2, [r1]

        ; collision detection goes here

        cmp r7, #0x11
        ldmeqfd sp!, {r1-r7, lr}
        bxeq lr

        ; lose a life
        cmp r7, #0x01
        ldmnefd sp!, {r1-r7, lr}
        bxne lr

        ldr r7, =lvl_lives
        ldrb r6, [r7]
        and r5, r6, #0xf
        bic r6, r6, #0xf
        orr r6, r6, r5, lsl #1
        strb r6, [r7]

        ldmfd sp!, {r1-r7, lr}
        bx lr

; set_mario
; parameters: none
; returns: none
;
; Sets mario in the starting position, replacing the old one with previous
; previous character
set_mario
        stmfd sp!, {r1-r7, lr}

        ; r1 - address of mario's position
        ; r2 - mario's position
        ; r3 - parsed position
        ; r4 - environment
        ; r5 - character swap
        ; r6 - scratchpad0
        ; r7 - scratchpad1

        ldr r1, =mario_pos
        ldr r4, =map
        ldr r2, [r1]

        ; parse position
        ; 18y + x
        and r3, r2, #0x1f0          ; isolate y-position, and get 16y
        add r3, r3, r3, lsr #3      ; get 18y
        and r6, r2, #0xf            ; isolate x-position
        add r3, r3, r6              ; 18y + x

        ; replaced character
        mov r5, r2, lsr #10
        strb r5, [r4, r3]

        ldr r2, =0x8151
        str r2, [r1]

        mov r5, #36
        ldr r3, =0x17b
        strb r5, [r4, r3]

        ldmfd sp!, {r1-r7, lr}
        bx lr

; ln_swap
; parameters:
;     r0 - address of line 1
;     r1 - address of line 2
; 
;     NOTE: assumes both lines are the same length
;
; returns: none
;
; Assuming both lines are the same, swap them. A line is considered to have
; ended when a newline character and carriage return has been encountered.
; Doesn't matter which order.
ln_swap
        stmfd sp!, {r0-r4, lr}

        mov r4, #0

nextc   ldrb r2, [r0]
        ldrb r3, [r1]
        strb r2, [r1], #1
        strb r3, [r0], #1
        cmp r2, #10
        addeq r4, r4, #1
        cmp r2, #13
        addeq r4, r4, #1
        cmp r2, #0
        moveq r4, #2
        cmp r4, #2
        bne nextc

        ldmfd sp!, {r0-r4, lr}
        bx lr

        end 
