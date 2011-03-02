    area interrupts, code, readwrite
    export lab5
    export FIQ_Handler

prompt = "Welcome to lab #5",0
    align
pinsel0 equ 0xe002c000
extint equ 0xe01fc140
extmode equ 0x8
vicbaseaddr equ 0xfffff000
vicintenable equ 0x10
vicintselect equ 0xc

lab5        
        stmfd sp!, {lr}


        ldmfd sp!,{lr}
        bx lr

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
