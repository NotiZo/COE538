;*****************************************************************
;* Demonstration Program                                         *
;* *
;* This program illustrates how to use the assembler.            *
;* It multiplies together two 8 bit numbers and leaves the result*
;* in the ‘$3000’ location.                                      *
;* Author: Raymond Cao Jiang 501183087                           *
;*****************************************************************

; export symbols
            XDEF Entry, _Startup        ; export 'Entry' symbol
            ABSENTRY Entry              ; for absolute assembly: mark this as application entry point

; Include derivative-specific definitions 
		INCLUDE 'derivative.inc' 

;*****************************************************************
;* Code Section                                                  *
;*****************************************************************
            ORG $3000
       
MULTIPLICAND    FCB 05                  ; first student num memory
MULTIPLIER      FCB 07                  ; last student num
PRODUCT         RMB 2                   ; reserve two memory bytes product of multiplication

;*****************************************************************
;* The actual program starts here                                *
;*****************************************************************
            ORG   $4000
Entry:
_Startup:
        LDAA MULTIPLICAND               ; get first number into ACCA Load accumulator A
        LDAB MULTIPLIER                 ; get second number into ACCB Load accumulator B
        MUL                             ; multiply the two 8-bit numbers A and B
        STD PRODUCT                     ; store product into  D
        SWI                             ; end program

;**************************************************************
;*                 Interrupt Vectors                          *
;**************************************************************
            ORG   $FFFE
            DC.W  Entry           ; reset Vector

