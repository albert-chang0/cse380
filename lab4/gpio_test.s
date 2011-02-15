    area    gpio, code, readwrite   
    export lab4

piodata equ 0x8 ; Offset to parallel I/O data register

prompt  = "Welcome to lab #4 ",0    ; Text to be sent to PuTTy
digits_SET  dcd 0x00001F80  ; 0
            dcd 0x00003000  ; 1 
            dcd 0x00003880  ; F


        align
lab4
        stmfd sp!,{lr}  ; Store register lr on stack


        ldmfd sp!, {lr} ; Restore register lr from stack    
        bx lr
    
        end
