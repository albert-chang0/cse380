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

        ; setup gpio, makes sure ports 0.7-0.13 are for gpio by zeroing them.
        ldr r0, =pinsel0
        ldr r1, [r0]
        bic r1, r1, #0xff00000
        bic r1, r1, #0xfc000
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

        ; push button setup      
        ldr r0, =pinsel0
        ldr r1, [r0]
        orr r1, r1, #0x20000000
        bic r1, r1, #0x10000000
        str r1, [r0]                    ; PINSEL0 bits 29:28 = 10

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
; parameters:
;     r0 - seed
; returns:
;     r0 - generated random number
;
; Uses the linear congruential generator algorithm to generate a random
; number based on the seed. The equation for lcg is:
;
; rand = {a * x_n + c} % m
;
; m is understood to be 2^32
rand
        stmfd sp!, {r1, r2, lr}

        ldr r1, =16644525       ; well chosen number for variable a
        ldr r2, =32767          ; well chosen number for variable c
        mla r0, r1, r0, r2

        ldmfd sp!, {r1, r2, lr}
        bx lr

FIQ_Handler
        stmfd sp!, {r0-r12, lr}


        ldmfd sp!, {r0-r12, lr}
        subs pc, lr, #4

        end 
