    area    gpio, code, readwrite   
    export lab4

piodata equ 0x8         ; Offset to parallel I/O data register
pinsel0 equ 0xe002c000
pinsel1 equ 0x4         ; offset from pinsel0
iobase equ 0xe0028000
                        ; io0pin has no offset
io0set equ 0x4
io0dir equ 0x8
io0clr equ 0xc
io1pin equ 0x10
io1set equ 0x14
io1dir equ 0x18
io1clr equ 0x1c

prompt  = "Welcome to lab #4 ",0    ; Text to be sent to PuTTy
digits_set  dcd 0x00001F80  ; 0
            dcd 0x00000300  ; 1 
            dcd 0x00002d80  ; 2
            dcd 0x00002780  ; 3
            dcd 0x00003300  ; 4
            dcd 0x00003680  ; 5
            dcd 0x00003e80  ; 6
            dcd 0x00000380  ; 7
            dcd 0x00003f80  ; 8
            dcd 0x00003780  ; 9
            dcd 0x00003b80  ; A
            dcd 0x00003e00  ; b
            dcd 0x00001c80  ; C
            dcd 0x00002f00  ; d
            dcd 0x00003c80  ; E
            dcd 0x00003880  ; F
        align
lab4
        stmfd sp!,{lr}  ; Store register lr on stack

        ; setup pin connection block
        ldr r0, =pinsel0
        mov r1, #0
        str r1, [r0]
        ; set direction for each pin

        ldmfd sp!, {lr} ; Restore register lr from stack    
        bx lr
    
        end
