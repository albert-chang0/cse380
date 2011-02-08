	AREA	Serial, CODE, READWRITE	
	EXPORT lab3
	
	U0LSR EQU 0x14			; UART0 Line Status Register

; You'll want to define more constants to make your code easier 
; to read and debug


lab3
	STMFD SP!,{lr}	; Store register lr on stack

; Your code is placed here

	LDMFD SP!, {lr}	; Restore register lr from stack	
	BX lr
	END
