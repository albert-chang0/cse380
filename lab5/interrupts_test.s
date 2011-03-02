    area interrupts, code, readwrite

    export lab5
    export FIQ_Handler

    extern uart_init
    extern output_character
    extern read_character
    extern output_string
    extern read_string
    extern display_digit

pinsel0 equ 0xe002c000      ; pin select
iobase equ 0xe0028000
io0dir equ 0x8
extint equ 0xe01fc140       ; external interrupt flag
extmode equ 0x8             ; external interrupt mode control
vicbaseaddr equ 0xfffff000  ; vic base address
vicintenable equ 0x10       ; interrupt enable
vicintselect equ 0xc        ; select fiq or irq

prompt = "Welcome to Interrupt Test!",0
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

        ldmfd sp!,{lr}
        bx lr

; interrupt_init
; parameters: none
; returns: none
;
; Enables and configures fast interrupts, disables normal interrupt.
; Uses external interrupt 1 and classifies it as a fast interrupt.
interrupt_init       
        stmfd sp!, {r0, r1, lr}         ; Save registers 

        ; Push button setup      
        ldr r0, =pinsel0
        ldr r1, [r0]
        orr r1, r1, #0x20000000
        bic r1, r1, #0x10000000
        str r1, [r0]                    ; PINSEL0 bits 29:28 = 10

        ; Classify sources as IRQ or FIQ
        ldr r0, =vicbaseaddr
        ldr r1, [r0, #vicintselect]
        orr r1, r1, #0x8000             ; External Interrupt 1
        str r1, [r0, #vicintselect]

        ; Enable Interrupts
        ldr r0, =vicbaseaddr
        ldr r1, [r0, #vicintenable] 
        orr r1, r1, #0x8000             ; External Interrupt 1
        str r1, [r0, #vicintenable]

        ; External Interrupt 1 setup for edge sensitive
        ldr r0, =extint
        ldr r1, [r0, #extmode]
        orr r1, r1, #2                  ; EINT1 = Edge Sensitive
        str r1, [r0, #extmode]

        ; Enable FIQ's, Disable IRQ's
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
; Fast interrupt handler
FIQ_Handler
        stmfd sp!, {r0-r12, lr}         ; Save registers 

eint1                                   ; Check for EINT1 interrupt
        ldr r0, =extint
        ldr r1, [r0]
        tst r1, #2
        beq fiq_exit

        stmfd sp!, {r0-r12, lr}         ; Save registers 


        ldmfd sp!, {r0-r12, lr}         ; Restore registers

        orr r1, r1, #2                  ; Clear Interrupt
        str r1, [r0]

fiq_exit
        ldmfd sp!, {r0-r12, lr}
        subs pc, lr, #4

    end
