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
      "|$          H  |",10,13,\
      "+==============+",0
        align

mario_pos dcd 0
next_rand dcd 0
score dcw 0
lives dcb 0xf
lvl dcb 1
jump_flag dcb 0
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
        stmfd sp!, {lr}  ; Store register lr on stack

        ; start clock
        ldr r3, =rtcbase
        mov r0, #1
        str r0, [r3, #ccr]

        bl uart_init

        bl interrupt_init

        ; setup display, makes sure ports 0.7-0.13 are for gpio by zeroing them.
        ; setup push button
        ldr r0, =pinsel0
        ldr r1, [r0]
        bic r1, r1, #0xff00000
        bic r1, r1, #0xfc000
        orr r1, r1, #0x20000000 bic r1, r1, #0x10000000
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

        ; start timer
        ldr r0, =timer0
        mov r1, #1
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
        stmfd sp!, {lr}

        ; classify sources as IRQ or FIQ
        ldr r0, =vicbaseaddr
        ldr r1, [r0, #vicintselect]
        orr r1, r1, #0x50               ; UART0 and TIMER0
        orr r1, r1, #0xa000             ; EINT1 and RTC
        str r1, [r0, #vicintselect]

        ; enable interrupts
        ldr r1, [r0, #vicintenable]
        orr r1, r1, #0x50               ; UART0 and TIMER0
        orr r1, r1, #0xa000             ; EINT1 and RTC
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

        ldmfd sp!, {lr}
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

        ldmfd sp!, {r1-r3 lr}
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
        beq uart0
; reset interrupt orr r1, r1, #2
        str r1, [r0, #tir]

        mov r0, #12
        bl output_character

        ; update barrels

        ; print map

        ldmfd sp!, {r0-r12, lr}         ; exit FIQ
        subs pc, lr, #4

        ; uart0 input?
uart0   ldr r0, =u0base
        ldr r1, [r0, #u0iir]
        tst r1, #1                  ; no pending interrupts
        beq eint1

        ; stop timer
        ldr r0, =timer0
        mov r1, #0
        str r1, [r0, #0]

        bl read_character
        ldr r1, =mario_pos
        ldr r3, [r2]

        ; up
        cmp r0, #119

        ; down
        cmp r0, #115

        ; left
        cmp r0, #97

        ; right
        cmp r0, #100

        ; update map
        mov r0, #0xc
        bl output_character
        ldr r0, =map
        bl output_string

        ; jump
        cmp r0, #32

        str r3, [r2]

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

        ldmfd sp!, {r0-r12, lr}
        subs pc, lr, #4

        end 
