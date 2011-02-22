    area    serial, code, readwrite 
    export lab3
    
pinsel0 equ 0xe002c000      ; UART0 pin select
u0base equ 0xe000c000       ; UART0 base address
u0lsr equ 0x14              ; UART0 line status register
u0lcr equ 0xc               ; UART0 line control register
u0dlm equ 0x4               ; UART0 divisor latch MSB register
                            ; UART0 divisor latch LSB register has no offset
prompt  = "Enter a number:  ",0          
; 32-byte strings (allows for longer than accepted inputs in case user doesn't
; obey
; Use null characters instead of actual 0s
string1 = 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
string2 = 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
string3 = 0,0,0,0,0,0
limit   = "99999"
        align

; lab3
; parameters: none
; returns: none
;
; Main routine. Allows user to enter data through PuTTY, providing feedback
; by displaying what is written. Asks the user to input two numbers between
; the ranges of 0 and 99,999. The input is terminated when the user hits
; Enter, and the string should be stored null terminated. Should not ask
; how many digits the user wants to put in; the program should determine
; length on its own. Assumes the user doesn't input numbers with commas.
lab3
        stmfd sp!,{lr}  ; Store register lr on stack

        ; r1 - fetched from memory
        ; r2 - number assembly
        ; r3 - scratchpad
        ; r4 - temporary hold for first number
        ; r5 - upper limit/temporary hold for second number
        ;      NOTE: immediates are limited to 255 and a rotation (1020)
        mov r2, #0
        ldr r5, =limit
        bl uart_init

        ; prompt user
        ldr r0, =prompt
        bl output_string

        ; location of string1
        ldr r0, =string1

        ; receiver first user input and validate it
invld1  bl read_string

        ldr r0, =string1

        ; convert ascii into integer
asmno1  ldrb r1, [r0], #1

        ; checks for null character
        cmp r1, #0
        beq bloop1      ; "break" loop

        ; check if it's larger than 99,999
        ; performed here so we can get out of this as quickly as possible
        cmp r2, r5
        bgt invld1

        ; checks if ascii values are numbers
        ; since negative numbers start with -, this will also check for values
        ; less than 0.
        cmp r1, #48
        blt invld1
        cmp r1, #57
        bgt invld1

        ; actual conversion of ascii to integer
        sub r1, r1, #48

        ; put the numbers together
        ; r2 = r2 * 10 + r1
        mov r3, r2, lsl #3
        add r3, r3, r2, lsl #1
        add r2, r3, r1
        b asmno1

bloop1  mov r4, r2

        ldr r0, =prompt
        bl output_string

        mov r2, #0

        ldr r0, =string2

invld2  bl read_string

        ldr r0, =string2

        ; convert ascii into integer
asmno2  ldrb r1, [r0], #1

        ; checks for null character
        cmp r1, #0
        beq bloop2      ; "break" loop

        ; check if it's larger than 99,999
        ; performed here so we can get out of this as quickly as possible
        cmp r2, r5
        bgt invld1

        ; checks if ascii values are numbers
        ; since negative numbers start with -, this will also check for values
        ; less than 0.
        cmp r1, #48
        blt invld1
        cmp r1, #57
        bgt invld2

        ; convert ascii to integer
        sub r1, r1, #48

        ; put numbers together
        ; r2 = r2 * 10 + r1
        mov r3, r2, lsl #3
        add r3, r3, r2, lsl #1
        add r2, r3, r1
        b asmno2

bloop2  mov r5, r2

        ; outputs:
        ; string1 % string2 = string3
        ; print out string1
        ldr r0, =string1
        bl output_string

        ; print out " % "
        mov r0, #32
        bl output_character
        mov r0, #37
        bl output_character
        mov r0, #32
        bl output_character

        ; print out string2
        ldr r0, =string2
        bl output_string

        ; print out " = "
        mov r0, #32
        bl output_character
        mov r0, #61
        bl output_character
        mov r0, #32
        bl output_character

        ; perform the actual modulo function
        mov r1, r4
        mov r0, r5
        bl mod

        ; convert binary integer to string of integer for printing
        mov r1, r0              ; r1 will hold what needs to go to RAM
        ldr r2, =string3
        add r2, r2, #4

strtoi  mov r0, #10
        bl mod                  ; isolate last number
        add r0, r0, #48         ; convert integer to ascii by adding 48
        strb r0, [r2], #-1      ; concat to beginning of string3
        cmp r1, #0
        bne strtoi

        add r0, r2, #1 ; get last character placed in string
        bl output_string

        mov r0, #0xa
        bl output_character
        mov r0, #0xd
        bl output_character

        ldmfd sp!, {lr} ; Restore register lr from stack    
        bx lr

; uart_init
; parameters: none
; returns: none
;
; Enables and configures the UART we are going to use (UART0).
; Basically a translation of the function serial_init() in mod_ui_wrapper.c.
uart_init
        stmfd sp!, {r1-r12, lr}

        ldr r1, =pinsel0

        ; enable UART0
        ldr r0, [r1]
        bic r0, r0, #0xf
        orr r0, r0, #0x5
        str r0, [r1]

        ldr r1, =u0base

        ; configurations:
        ; 8-bit word length
        ; 1 stop bit
        ; no parity
        ; disable break control
        ; enable latch access
        mov r0, #0x83
        strb r0, [r1, #u0lcr]

        ; 9600 baud rate:
        mov r0, #0x78
        strb r0, [r1]
        mov r0, #0
        strb r0, [r1, #u0dlm]

        ; disable latch access
        mov r0, #3
        strb r0, [r1, #u0lcr]

        ldmfd sp!, {r1-r12, lr}
        bx lr

; output_character
; parameters:
;     r0 - character to output to UART
; returns: none
;
; Taken from the first part of lab3, this accepts a parameter from register
; r0, and outputs it to UART.
output_character
        stmfd sp!, {r1-r12, lr}

        ldr r2, =u0base         ; UART0 base address

tpoll   ldrb r1, [r2, #u0lsr]   ; load status register
        and r1, r1, #0x20       ; test THRE
        cmp r1, #0
        beq tpoll               ; poll until ready to write

        strb r0, [r2]           ; write to UART register

        ldmfd sp!, {r1-r12, lr}
        bx lr

; read_character
; parameters: none
; returns:
;     r0 - character read in from UART
;
; Taken from the first part of lab3, this reads from UART and returns it in
; register r0.
read_character
        stmfd sp!, {r1-r12, lr}

        ldr r2, =u0base         ; UART0 base address

rpoll   ldrb r1, [r2, #u0lsr]   ; load status register
        and r1, r1, #1          ; test RDR
        cmp r1, #0
        beq rpoll               ; poll until something needs to be read

        ldrb r0, [r2]           ; read receiver buffer

        ldmfd sp!, {r1-r12, lr}
        bx lr

; output_string
; parameters:
;     r0 - base address of string to be printed
; returns: none
;
; Displays a null terminated string, which the base address is passed in
; through register r0, to UART.
output_string
        stmfd sp!, {r1-r12, lr}

        mov r1, r0

soloop  ldrb r0, [r1], #1
        cmp r0, #0
        blne output_character
        bne soloop

        ldmfd sp!, {r1-r12, lr}
        bx lr

; read_string
; parameters:
;    r0 - base address of string
; returns: none
;
; Reads in a string from UART and stores the base address in register r0.
read_string
        stmfd sp!, {r1-r12, lr}

        mov r1, r0

read    bl read_character
        bl output_character     ; give instant feedback
        ; output non-printable characters, but don't store them
        mov r2, #0
        cmp r0, #32
        addge r2, #1
        cmpge r0, #126
        addle r2, #1
        cmp r2, #2
        strbeq r0, [r1], #1
        cmp r0, #0xd            ; returns on carriage return
        bne read

        ; store null character
        mov r0, #0
        strb r0, [r1]

        mov r0, #0xa
        bl output_character
        mov r0, #0xd
        bl output_character

        mov r1, r0

        ldmfd sp!, {r1-r12, lr}
        bx lr

; mod
; parameters:
;     r0 - divisor
;     r1 - dividened
; returns:
;     r0 - modulo of r0 and r1 (r1 % r0)
;     r1 - quotient of r0 and r1 (r1 / r0)
;
; Performs a modulo (remainder of a divide function) on the parameters
; passed through registers r0 and r1. The function should follow:
; r1 modulo r0 (r1 % r0)
; The majority of the function is taken from lab 2's division subroutine.
mod
        stmfd sp!, {r2-r12, lr}

        ; r0 - divisor
        ; r1 - dividend
        ; r2 - quotient
        ; r3 - remainder
        ; r4 - counter
        mov r2, #0          ; initialize quotient to 0
        mov r3, r1          ; initialize remainder to dividend
        mov r4, #0x10       ; initialize counter to 16
        mov r0, r0, lsl #0x10 ; logical left shift divisor 16 places
cloop   sub r3, r3, r0 ; remainder = remainder - divisor; cloop is the counter loop
        cmp r3, #0          ; remainder < 0
        blt rless
        mov r2, r2, lsl #1  ; left shift quotient
        add r2, r2, #1      ; lsb = 1
shftd   mov r0, r0, lsr #1  ; right shift divisor, msb = 0

        cmp r4, #0          ; counter > 0
        ble exit   ; counter <= 0 instead reduces number of branching instructions
        sub r4, r4, #1      ; decrement counter
        b cloop

exit    mov r0, r3          ; return remainder instead of quotient
        mov r1, r2          ; also return quotient

        ldmfd sp!, {r2-r12, lr}
        bx lr               ; Return to the C program    

rless   add r3, r3, r0      ; remainder = remainder + divisor
        mov r2, r2, lsl #1  ; left shift quotient, lsb = 0
        b shftd

        end
