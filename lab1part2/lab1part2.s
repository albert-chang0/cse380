	AREA	Lab1Part2, CODE, READONLY	
	ENTRY
		
main	MOV r5, #17		; How many consecutive integers can be
                    	; summed (starting with 1) before
                     	; the sum exceeds the value stored
				     	; in r5?  Place the answer in r5.
		MOV r1, #1		; Initialize r1		
		MOV r2, #0		; Initialize r2
LOOP	ADD r1, r1, #1	; Increment r1 by 1
		ADD r2, r1, r2 	; Calculate running sum
		CMP r2, r5		; Test
		BLE LOOP
			
		SUB r5, r1, #1	; Adjustment.  Store answer in r5.
		
STOP	MOV	r0, #0x18
		LDR	r1, =0x20026
		SWI	0x0123456
			
	END
