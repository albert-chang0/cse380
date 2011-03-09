    area curses, code, readwrite 

    export lab6
    export FIQ_Handler

    extern uart_init
    extern output_character
    extern read_character
    extern output_string

u0base equ 0xe000c000       ; UART0 base address
u0ier equ 0x4               ; UART0 interrupt enable register
u0iir equ 0x8               ; UART0 interrupt identification register
vicbaseaddr equ 0xfffff000  ; vic base address
vicintenable equ 0x10       ; interrupt enable
vicintselect equ 0xc        ; select fiq or irq
timer0 equ 0xe0004000
tc equ 0x8
mcr equ 0x14
tir equ 0x0
tcr equ 0x4
mr1 equ 0x1c

t_b_box = "+--------------------+",10,13,0
pos = 1
dir = 0
pause = 0
fill = "|*                   |",10,13,0
prompt = "Welcome to ARM curses test.",10,13,\
         "+/- adjusts speed by a factor of 2",10,13,\
         "h/l changes direction",10,13,10,13,0
    align

; lab6
; parameters: none
; returns: none
;
; Provides a GUI-like environment for the terminal, similar to what the MIT
; curses library does and pcurses or ncurses. An asterisk bounces back and
; forth. It accepts 4 keystrokes:
; +: doubles speed
; -: halves speed
; h/H: move in the left direction
; l/L: move in the right direction
; q/Q: quit
; It uses two interrupts: timer and uart. After a certain amount of time, the
; display is updated, and when a keystroke is entered, it takes the appropriate
; action.
lab6
        stmfd sp!,{lr}  ; Store register lr on stack

        bl uart_init
        bl interrupt_init

        ; initial speed of ~1char/s
        ldr r0, =timer0
        ldr r1, =0x2dc6c0
        str r1, [r0, #mr1]

        ldr r0, =prompt
        bl output_string

        ldr r0, =t_b_box
        bl output_string

        ldr r0, =fill
        bl output_string

        ldr r0, =t_b_box
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
; Sets up the necessary interrupts: timer and uart. Classifies them as fast
; interrupt for convenience.
interrupt_init
        stmfd sp!, {r0, r1, lr}

        ; classify sources as IRQ or FIQ
        ldr r0, =vicbaseaddr
        ldr r1, [r0, #vicintselect]
        orr r1, r1, #0x50               ; UART0 and TIMER0
        str r1, [r0, #vicintselect]

        ; enable interrupts
        ldr r1, [r0, #vicintenable]
        orr r1, r1, #0x50               ; UART0 and TIMER0
        str r1, [r0, #vicintenable]

        ; UART0 interrupt on RX
        ldr r0, =u0base
        ldr r1, [r0, #u0ier]
        orr r1, r1, #1
        str r1, [r0, #u0ier]

        ; TIMER0 interrupt
        ldr r0, =timer0
        ldr r1, [r0, #mcr]
        orr r1, r1, #0x38
        str r1, [r0, #mcr]

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
; Fast interrupt handler. Checks what caused the interrupt. If it's the timer,
; it's time to update the output. If it's the uart, see what the user wants to
; do. When updating the output, also check to see if the direction needs to be
; changed (when it reaches the end of the box). Position and direction are
; stored into RAM.
FIQ_Handler
        stmfd sp!, {r0-r12, lr}

        ; timer0 matched
        ldr r0, =timer0
        ldr r1, [r0, #tir]
        tst r1, #2
        beq uart0

        ; reset interrupt
        orr r1, r1, #2
        str r1, [r0, #tir]

        ldr r0, =pause
        ldrb r0, [r0]

        ; if it is paused, already up-to-date
        ; do nothing
        cmp r4, #1
        beq reset

        mov r0, #12
        bl output_character

        ldr r0, =prompt
        bl output_string

        ldr r0, =t_b_box
        bl output_string

        ; r0 - address of string being changed
        ; r1 - position address
        ; r2 - direction address
        ; r3 - position
        ; r4 - direction
        ; r5 - scratchpad

        ldr r0, =fill

        ; get position
        ldr r1, =pos
        ldrb r3, [r1]

        ; get direction
        ldr r2, =dir
        ldrsb r4, [r2]

        ; replace old position with a space
        mov r5, #32
        strb r5, [r0, r3]

        ; if at the beginning, switch to positive direction
        cmp r3, #1
        moveq r4, #1

        ; if at the end, switch to negative direction
        cmp r3, #20
        mvneq r4, #0

        ; update position
        add r3, r3, r4
        mov r5, #42
        strb r5, [r0, r3]

        ; save position and direction
        strb r3, [r1]
        strb r4, [r2]

        bl output_string

        ldr r0, =t_b_box
        bl output_string

        ; reset count and enable clock
reset   ldr r0, =timer0
        mov r1, #2
        str r1, [r0, #tcr]
        mov r1, #1
        str r1, [r0, #tcr]

        ; uart0 input?
uart0   ldr r0, =u0base
        ldr r1, [r0, #u0iir]
        tst r1, #1                  ; no pending interrupts

        ldmnefd sp!, {r0-r12, lr}
        subnes pc, lr, #4           ; exit FIQ

        bl read_character

        ; get speed
        ldr r1, =timer0
        ldr r2, [r1, #mr1]

        ; '+' - increase speed
        cmp r0, #43
        moveq r2, r2, lsr #1

        ; '-' - decrease speed
        cmp r0, #45
        moveq r2, r2, lsl #1

        ; ' ' - pause/restart
        cmp r0, #32
        ldr r1, =pause
        ldreqb r2, [r1]
        eoreq r2, r2, #1
        streqb r2, [r1]

        ; change speed
        str r2, [r1, #mr1]

        ldmfd sp!, {r0-r12, lr}
        subs pc, lr, #4

        end 
