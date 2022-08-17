.MODEL SMALL
.STACK 1000

.DATA
x1 DW 100 DUP(?)

.CODE

CR EQU 0DH
LF EQU 0AH
NG EQU 2DH

PRINT PROC          
     	
    XOR CX, CX
    XOR DX, DX
		;fast init
    	;print value is in ax 
    	
	CMP AX, 0
	JE PRINT_ZERO
	JNL PUSH_NUMBER_LOOP
	
	PUSH AX
	MOV AH, 02H
	MOV DL, '-'
	INT 21H
	POP AX
	NEG AX
		;print '-' if negative value
	XOR DX,DX
		;fix dx value to 0
	
    	PUSH_NUMBER_LOOP:

        	CMP AX, 0
        	JE PRINT_LOOP  
         
        	MOV BX, 10
			;divide by 10  
         
        	DIV BX
        	PUSH DX
		INC CX
			;mod in stack            
                     
        	XOR DX, DX
        	JMP PUSH_NUMBER_LOOP

    	PRINT_LOOP:
        	POP DX
			MOV AH, 02H
        	ADD DX, 30H
        	INT 21H
        	 
        	LOOP PRINT_LOOP
	END_PRINT_LOOP:

		MOV AH, 02H
		MOV DL, CR
		INT 21H
		MOV DL, LF
		INT 21H

	RET
	
	PRINT_ZERO:
	
		MOV AH, 02H
		MOV DL, '0'
		INT 21H
		MOV DL, CR
		INT 21H
		MOV DL, LF
		INT 21H
	
	RET
		
PRINT ENDP 
INPUT PROC

    ; fast BX = 0
    XOR BX, BX
    
    INPUT_LOOP:
    ; char input 
    MOV AH, 1
    INT 21H
    
    ; if \n\r, stop taking input
    CMP AL, CR    
    JE END_INPUT_LOOP
    CMP AL, LF
    JE END_INPUT_LOOP
    
    ; fast char to digit
    ; also clears AH
    AND AX, 000FH
    
    ; save AX 
    MOV CX, AX
    
    ; BX = BX * 10 + AX
    MOV AX, 10
    MUL BX
    ADD AX, CX
    MOV BX, AX
    JMP INPUT_LOOP
    
    END_INPUT_LOOP:
    ; value stored in BX
    
    ; printing CR and LF
    MOV AH, 2
    MOV DL, CR
    INT 21H
    MOV DL, LF
    INT 21H

    RET
    
INPUT ENDP
;------------------------------------------------------------------------
;------------------------Compiled Code-----------------------------------
;------------------------------------------------------------------------
     
MAIN PROC
MOV AX, @DATA
MOV DS, AX
PUSH BP
MOV BP, SP
SUB SP, 2
XOR AX, AX
;MOV AX, [BP - 4] Optimized
MOV [BP - 4], AX
MOV [BP - 2], AX
__lebel_forLoopStart_0:
MOV AX, 5
MOV [BP - 4], AX
MOV AX, [BP - 2]
MOV BX, [BP - 4]
CMP AX, BX
JL __lebel0
MOV AX, 0
MOV [BP - 6], AX
JMP __lebel1
__lebel0:
MOV AX, 1
MOV [BP - 6], AX
__lebel1:
XOR AX, AX
CMP AX, [BP - 6]
JE __lebel_forLoopEnd_1
JMP __lebel_forLoopStatement_2
__lebel_forLoopChange_3:
MOV AX, [BP - 2]
MOV [BP - 4], AX
INC [BP - 2]
JMP __lebel_forLoopStart_0
__lebel_forLoopStatement_2:
MOV SI, x1
MOV AX, [BP - 2]
SHL AX, 1
ADD SI, AX
MOV AX, [SI]
MOV [BP - 6], AX
MOV [BP - 8], SI
SUB SP, 10
CALL INPUT
MOV [BP - 10], BX
ADD SP, 10
MOV AX, [BP - 10]
MOV SI, [BP - 8]
MOV [SI], AX
JMP __lebel_forLoopChange_3
__lebel_forLoopEnd_1:
XOR AX, AX
;MOV AX, [BP - 4] Optimized
MOV [BP - 4], AX
MOV [BP - 2], AX
__lebel_forLoopStart_4:
MOV AX, 5
MOV [BP - 4], AX
MOV AX, [BP - 2]
MOV BX, [BP - 4]
CMP AX, BX
JL __lebel2
MOV AX, 0
MOV [BP - 6], AX
JMP __lebel3
__lebel2:
MOV AX, 1
MOV [BP - 6], AX
__lebel3:
XOR AX, AX
CMP AX, [BP - 6]
JE __lebel_forLoopEnd_5
JMP __lebel_forLoopStatement_6
__lebel_forLoopChange_7:
MOV AX, [BP - 2]
MOV [BP - 4], AX
INC [BP - 2]
JMP __lebel_forLoopStart_4
__lebel_forLoopStatement_6:
MOV SI, x1
MOV AX, [BP - 2]
SHL AX, 1
ADD SI, AX
MOV AX, [SI]
MOV [BP - 6], AX
MOV [BP - 8], SI
SUB SP, 8
MOV AX, [BP - 6]
CALL PRINT
ADD SP, 8
JMP __lebel_forLoopChange_7
__lebel_forLoopEnd_5:
__main_return: 
MOV SP, BP
PUSH DX
MOV SP, BP
POP BP
MOV AH,4CH
INT 21h
MAIN ENDP
END MAIN
