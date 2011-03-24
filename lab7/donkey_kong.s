    area donkey_kong, code, readwrite 

    export game 
    export FIQ_Handler

    extern output_string
    extern uart_init
    extern output_character
    extern read_character

pinsel0 equ 0xe002c000      ; pin select
rtcbase equ 0xe0024000      ; rtc base address
ccr equ 0x8                 ; clock counter register
ctc equ 0x4
ctime0 equ 0x14             ; clock consolidated time
u0base equ 0xe000c000       ; UART0 base address
u0ier equ 0x4               ; UART0 interrupt enable register
u0iir equ 0x8               ; UART0 interrupt identification register
iobase equ 0xe0028000
io0dir equ 0x8
extint equ 0xe01fc140       ; external interrupt flag
extmode equ 0x8             ; external interrupt mode control
timer0 equ 0xe0004000
timer1 equ 0xe0008000
tc equ 0x8
mcr equ 0x14
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
      "|&@    H       |",10,13,\
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
      "|$          H  |",10,13,\
      "+==============+",0
        align

mario_pos dcd 0
next_rand dcd 0
barrels dcd 0x10262,0,0,0,0,0
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
        ;ldr r3, =rtcbase
        ;mov r0, #1
        ;str r0, [r3, #ccr]

        bl uart_init
        bl interrupt_init

        ; set initial barrel speed to ~1char/0.25s
        ldr r0, =timer0
        ldr r1, =0xb71b0
        str r1, [r0, #mr1]

        ; set initial barrel ejection frequency to ~1char/8s
        ldr r0, =timer1
        ldr r1, =0x16e3600
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
        ; P0.7-P0.13, output 7-segment
        ldr r0, =iobase
        ldr r1, [r0, #io0dir]
        orr r1, r1, #0x260000
        orr r1, r1, #0x3f80
        str r1, [r0, #io0dir]

        ; clear prompt
        mov r0, #0xc
        bl output_character

        ldr r0, =map
        bl output_string

        ;ldr r1, =rtcbase
        ;ldr r0, [r1, #ctime0]
        ;ldr r0, [r1, #ctc]
        ldr r0, =0xa3f4e
        bl srand

        ; reset timers
        mov r1, #2
        ldr r0, =timer0
        str r1, [r0, #tcr]
        ldr r0, =timer1
        str r1, [r0, #tcr]

        ; start timers
        mov r1, #1
        ldr r0, =timer0
        str r1, [r0, #tcr]
        ldr r0, =timer1
        str r1, [r0, #tcr]

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

; rand
; parameters: none
; returns:
;     r0 - generated random number
;
; Uses the linear congruential generator algorithm to generate a random
; number based on the seed. The equation for lcg is:
;
; rand = {a * x_n + c} % m
;
; m is understood to be 2^32. Variables a and c are chosen by the programmer
;
; glibc/gcc
; a = 1103515245
; c = 12345
; 
; Microsoft Visual
; a = 214013
; c = 2531011
;
; Java API
; a = 25214903917
; c = 11
rand
        stmfd sp!, {r1-r3, lr}

        ldr r3, =next_rand
        ldr r0, [r3]
        ldr r1, =1103515245
        ldr r2, =12345
        mla r0, r1, r0, r2
        str r0, [r3]

        ldmfd sp!, {r1-r3, lr}
        bx lr

; srand
; parameters:
;     r0 - seed
; returns: none
;
; Initializes the random number generator
srand
        stmfd sp!, {r1, lr}

        ldr r1, =next_rand
        str r0, [r1]

        ldmfd sp!, {r1, lr}
        bx lr

; FIQ_Handler
; parameters: none
; returns: none
;
; Fast interrupt handler.
; Timer interrupt:
;     Updates barrel position, adds a new barrel if necessary
; UART interrupt:
;     Moves Mario
; External interrupt
;     Disables UART and timer
FIQ_Handler
        stmfd sp!, {r0-r12, lr}

        ; timer0 matched
        ldr r0, =timer0
        ldr r1, [r0, #tir]
        tst r1, #2
        beq t1ir
        ; reset interrupt
        orr r1, r1, #2
        str r1, [r0, #tir]

        mov r0, #12
        bl output_character

        bl mv_barrel

        ldr r0, =map
        bl output_string

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

        ldr r0, =map
        bl output_string

        ldmfd sp!, {r0-r12, lr}
        subs pc, lr, #4             ; exit FIQ

        ; uart0 input?
uart0   ldr r0, =u0base
        ldr r1, [r0, #u0iir]
        tst r1, #1                  ; no pending interrupts
        beq eint1

        ; stop timer
        ldr r0, =timer0
        mov r1, #0
        str r1, [r0, #tcr]

        bl mv_mario

        ldr r0, =map
        bl output_string

        ldmfd sp!, {r0-r12, lr}
        subs pc, lr, #4                 ; exit FIQ

        ; push button?
eint1   ldr r0, =extint
        ldr r1, [r0]
        tst r1, #2

        ldmnefd sp!, {r0-r12, lr}
        subnes pc, lr, #4               ; exit FIQ

        ; clear external interrupt
        orr r1, r1, #2
        str r1, [r0]

        bl pause_button

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

        ;bl mv_mario

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
        cmp r8, #6
        ldmeqfd sp!, {r0-r8, lr}
        bxeq lr
        cmp r2, #0
        addeq r8, r8, #1
        beq bcloop

        ; parse position
        ; 18y + x
        ; isolate y-position
        mov r6, r2, lsr #4
        and r6, r6, #0x1f
        ; get 16y + x
        and r3, r2, #0xff
        and r7, r2, #0x100
        add r3, r3, r7
        ; get (16y + x) + 2y = 18y + x
        add r3, r3, r6, lsl #1

        ; get replaced character
        mov r5, r2, lsr #11
        strb r5, [r4, r3]            ; restore character
        bic r2, r2, #0xf800
        bic r2, r2, #0x70000

        mov r0, #0

        ; check if it's falling
        add r3, r3, #18
        ldrb r6, [r4, r3]
        cmp r6, #32                 ; nothing supporting barrel, definitely fall
        addeq r7, #2
        cmp r6, #35                 ; over a ladder, it could fall
        cmpne r6, #72
        moveq r7, #1
        cmp r5, #72                 ; mid-fall down unbroken ladder, definitely falling
        addeq r7, r7, #1
        cmp r6, #45
        cmpne r6, #61
        subeq r7, r7, #1
        cmp r7, #1                  ; if it could fall, should it?
        bleq rand
        and r0, r0, #1
        add r7, r7, r0
        cmp r7, #2
        subne r3, r3, #18
        bne mvbh                    ; not going to fall, move horizontally
        orr r2, r2, #0x400          ; set falling flag
        add r2, r2, #0x10           ; update position
        add r2, r2, r6, lsl #11     ; save replaced character
        mov r6, #64
        strb r6, [r4, r3]            ; move barrel

        str r2, [r1, r8]            ; update barrel
        add r8, r8, #1
        b bcloop

mvbh    ldr r6, =379
        cmp r3, r6
        bne move_b
        mov r2, #0
        add r8, r8, #1
        str r2, [r1, r8]
        b bcloop

move_b  tst r2, #0x400              ; if it had just fallen
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
        strb r5, [r4, r3]            ; move barrel

        str r2, [r1, r8]            ; update barrel
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
seek    ldr r1, [r0], #1            ; find first available space in RAM
        cmp r1, #0
        bne seek

        ; create barrel
        ldr r1, =0x10262
        str r1, [r0, #-1]

        ; draw barrel
        ldr r0, =map
        mov r1, #64
        str r1, [r0, #110]

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
;     9:10  controlled fall (jump)
;    11:18  previous char
;
; Some memory could be saved if there was no alignment since not all 32 bits
; are required to store information.
mv_mario
        stmfd sp!, {r1-r7, lr}
        
        ; r1 - address of mario's position
        ; r2 - mario's position
        ; r3 - parsed position
        ; r4 - environment
        ; r5 - character swap
        ; r6 - scratchpad0
        ; r7 - scratchpad1

        ldr r1, =mario_pos
        ldr r2, [r1]

        ; parse position
        ; 18y + x
        ; isolate y-position
        mov r6, r2, lsr #4
        and r6, r6, #0x1f
        ; get 16y + x
        and r3, r2, #0xff
        and r7, r2, #0x100
        add r3, r3, r7
        ; get (16y + x) + 2y = 18y + x
        add r3, r3, r6, lsl #1

        ; mid jump
        tst r2, #0x400
        bne mvm

        ; get replaced character
        mov r5, r2, lsr #11
        str r5, [r4, r3]            ; restore character
        bic r2, r2, #0xf800
        bic r2, r2, #0x70000

        ; check if it's falling
        add r3, r3, #18
        ldr r6, [r4, r3]
        cmp r6, #32                 ; nothing supporting Mario

mvm     bl read_character

        ldmfd sp!, {r1-r7, lr}
        bx lr

pause_button
        stmfd sp!, {lr}


        ldmfd sp!, {lr}

        end 
