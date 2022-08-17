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
    ;main function initialization
MAIN PROC


    ;data initialization
	MOV AX, @DATA
	MOV DS, AX


    ;function stack movement for recursive calling
	PUSH BP
	MOV BP, SP


    ;var declaration i
	SUB SP, 2


    ;CONST_INT: 0
	XOR AX, AX
	MOV [BP - 4], AX


    ;i = 0
	MOV AX, [BP - 4]
	MOV [BP - 2], AX


    ;for loop start
	__lebel_forLoopStart_0:


    ;CONST_INT: 5
	MOV AX, 5
	MOV [BP - 4], AX


    ;i<5
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


    ;looping condition check
	XOR AX, AX
	CMP AX, [BP - 6]
	JE __lebel_forLoopEnd_1
	JMP __lebel_forLoopStatement_2
	__lebel_forLoopChange_3:


    ;i++
	MOV AX, [BP - 2]
	MOV [BP - 4], AX
	INC [BP - 2]


    ;looping variable change
	JMP __lebel_forLoopStart_0
	__lebel_forLoopStatement_2:


    ;array[expression]
	MOV SI, x1
	MOV AX, [BP - 2]
	SHL AX, 1
	ADD SI, AX
	MOV AX, [SI]
	MOV [BP - 6], AX
	MOV [BP - 8], SI


    ;input procedure
	SUB SP, 10
	CALL INPUT
	MOV [BP - 10], BX
	ADD SP, 10


    ;x[i] = INPUT()
	MOV AX, [BP - 10]
	MOV SI, [BP - 8]
	MOV [SI], AX


    ;looping statement finished
	JMP __lebel_forLoopChange_3
	__lebel_forLoopEnd_1:


    ;CONST_INT: 0
	XOR AX, AX
	MOV [BP - 4], AX


    ;i = 0
	MOV AX, [BP - 4]
	MOV [BP - 2], AX


    ;for loop start
	__lebel_forLoopStart_4:


    ;CONST_INT: 5
	MOV AX, 5
	MOV [BP - 4], AX


    ;i<5
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


    ;looping condition check
	XOR AX, AX
	CMP AX, [BP - 6]
	JE __lebel_forLoopEnd_5
	JMP __lebel_forLoopStatement_6
	__lebel_forLoopChange_7:


    ;i++
	MOV AX, [BP - 2]
	MOV [BP - 4], AX
	INC [BP - 2]


    ;looping variable change
	JMP __lebel_forLoopStart_4
	__lebel_forLoopStatement_6:


    ;array[expression]
	MOV SI, x1
	MOV AX, [BP - 2]
	SHL AX, 1
	ADD SI, AX
	MOV AX, [SI]
	MOV [BP - 6], AX
	MOV [BP - 8], SI


    ;printf(x[i])
	SUB SP, 8
	MOV AX, [BP - 6]
	CALL PRINT
	ADD SP, 8


    ;looping statement finished
	JMP __lebel_forLoopChange_7
	__lebel_forLoopEnd_5:


    ;return label of the function main
	__main_return: 


    ;removing all variable in the scope and storing the return value
	MOV SP, BP
	PUSH DX


    ;stack movement for recursive calling, [if return available then it is in DX]
	MOV SP, BP
	POP BP


    ;interrupt to return to operator
	MOV AH,4CH
	INT 21h


    ;main function ending
MAIN ENDP
END MAIN


    ;code finised
 


