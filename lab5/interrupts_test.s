    area interrupts, code, readwrite

    export lab5
    export FIQ_Handler

    extern uart_init
    extern output_character
    extern read_character
    extern output_string
    extern display_digit

pinsel0 equ 0xe002c000      ; pin select
u0base equ 0xe000c000       ; UART0 base address
u0ier equ 0x4               ; UART0 interrupt enable register
u0iir equ 0x8               ; UART0 interrupt identification register
iobase equ 0xe0028000
io0dir equ 0x8
extint equ 0xe01fc140       ; external interrupt flag
extmode equ 0x8             ; external interrupt mode control
vicbaseaddr equ 0xfffff000  ; vic base address
vicintenable equ 0x10       ; interrupt enable
vicintselect equ 0xc        ; select fiq or irq

prompt = "Welcome to Interrupt Test!",\
         10,13,"Enter numbers and letters.",10,13,\
         10,13,"Pushing the 5th push button turns off the display.",10,13,0
    align

; lab5
; parameters: none
; returns: none
;
; Reads hexadecimal from UART0, and illuminates digit on 7-segment display.
; Keep display illuminated until another digit is entered or user presses the
; user interrupt button, which turns off the display. All events handled by
; interrupts.
lab5        
        stmfd sp!, {lr}

        ; setup uart and fast interrupts
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

        ; prompt user
        ldr r0, =prompt
        bl output_string

        ldmfd sp!,{lr}
        bx lr

; interrupt_init
; parameters: none
; returns: none
;
; Enables and configures fast interrupts, disables normal interrupt.
; External interrupt 1 is for the push button. Classify external interrupt
; and UART as fast interrupts. Listen for read buffer register for UART interrupt.
interrupt_init       
        stmfd sp!, {r0, r1, lr}         ; Save registers 

        ; push button setup      
        ldr r0, =pinsel0
        ldr r1, [r0]
        orr r1, r1, #0x20000000
        bic r1, r1, #0x10000000
        str r1, [r0]                    ; PINSEL0 bits 29:28 = 10

        ; classify sources as IRQ or FIQ
        ldr r0, =vicbaseaddr
        ldr r1, [r0, #vicintselect]
        orr r1, r1, #0x8000             ; External Interrupt 1
        orr r1, r1, #0x40               ; UART0
        str r1, [r0, #vicintselect]

        ; enable Interrupts
        ldr r1, [r0, #vicintenable] 
        orr r1, r1, #0x8000             ; External Interrupt 1
        orr r1, r1, #0x40               ; UART0
        str r1, [r0, #vicintenable]

        ; external Interrupt 1 setup for edge sensitive
        ldr r0, =extint
        ldr r1, [r0, #extmode]
        orr r1, r1, #2                  ; EINT1 = Edge Sensitive
        str r1, [r0, #extmode]

        ; UART0 interrupt on RX
        ldr r0, =u0base
        ldr r1, [r0, #u0ier]
        orr r1, r1, #1                  ; RBR interrupt enable
        str r1, [r0, #u0ier]

        ; enable FIQ's, disable IRQ's
        mrs r0, cpsr
        bic r0, r0, #0x40
        orr r0, r0, #0x80
        msr cpsr_c, r0

        ldmfd sp!, {r0, r1, lr}         ; Restore registers
        bx lr                           ; Return

; FIQ_Handler
; parameters: none
; returns: none
;
; Fast interrupt handler. Checks what caused the interrupt. If it was the push
; button, clear the display and disable interrupts. If it was from the UART,
; validate user input. If it's valid, replace character in terminal and update
; 7-segment display.
FIQ_Handler
        stmfd sp!, {r0-r12, lr}         ; Save registers 

        ; push button?
        ldr r0, =extint
        ldr r1, [r0]
        tst r1, #2
        beq uart0                       ; not push button, check uart0

        ; clear external interrupt
        orr r1, r1, #2
        str r1, [r0]

        ; clear display
        mov r0, #-1
        bl display_digit

        ; exits program
        ; don't allow any inputs/disable interrupts
        mrs r0, cpsr
        bic r0, r0, #0xc0
        msr cpsr_c, r0

        ; uart0 input?
uart0   ldr r0, =u0base
        ldr r1, [r0, #u0iir]
        tst r1, #1                      ; no pending interrupts

        ldmnefd sp!, {r0-r12, lr}
        subnes pc, lr, #4               ; exit FIQ

        bl read_character

        mov r1, #0
        ; 0-9
        cmp r0, #48
        addge r1, r1, #1
        cmp r0, #57
        addle r1, r1, #1
        cmp r1, #2
        subeq r1, r0, #48       ; valid input, convert to numbers 0-9
        beq valid

        ; A-F
        mov r1, #0
        cmp r0, #65
        addge r1, r1, #1
        cmp r0, #70
        addle r1, r1, #1
        cmp r1, #2
        subeq r1, r0, #55       ; valid input, convert to numbers 10-15
        beq valid

        ; a-f
        mov r1, #0
        cmp r0, #97
        addge r1, r1, #1
        cmp r0, #102
        addle r1, r1, #1
        cmp r1, #2
        subeq r1, r0, #87       ; valid input, convert to numbers 10-15
        beq valid

        ldmfd sp!, {r0-r12, lr}
        subs pc, lr, #4         ; exit FIQ

        ; valid - replace previous character
        ; and update display
valid   bl output_character
        mov r0, #13
        bl output_character
        mov r0, r1
        bl display_digit

        ldmfd sp!, {r0-r12, lr}
        subs pc, lr, #4         ; exit FIQ

    end
