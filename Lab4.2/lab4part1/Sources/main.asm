;*****************************************************************
;* This stationery serves as the framework for a                 *
;* user application (single file, absolute assembly application) *
;* For a more comprehensive program that                         *
;* demonstrates the more advanced functionality of this          *
;* processor, please see the demonstration applications          *
;* located in the examples subdirectory of the                   *
;* Freescale CodeWarrior for the HC12 Program directory          *
;*****************************************************************

; export symbols
            XDEF Entry, _Startup            ; export 'Entry' symbol
            ABSENTRY Entry        ; for absolute assembly: mark this as application entry point

; Include derivative-specific definitions 
		INCLUDE 'derivative.inc' 

; variable/data section

; code section
            ORG   $4000
Entry:
_Startup:

;************************************************************
;*                      Motor Control                       *
;************************************************************
            BSET  DDRA,%00000011     ;  set PA0 and PA1 as output (motor direction control, 0 foward 1 reverse)
            BSET  DDRT,%00110000     ;  set PT4 and PT5 as output (motor on/off control, 1 for on 0 for off)
            JSR   STARFWD            ;  subroutines
            JSR   PORTFWD
            JSR   STARON
            JSR   PORTON
            JSR   STARREV
            JSR   PORTREV
            JSR   STAROFF
            JSR   PORTOFF
            BRA   *

STARON      LDAA  PTT                ;  AND and OR used to avoid affect all bits at once
            ORAA  #%00100000
            STAA  PTT
            RTS

STAROFF     LDAA  PTT
            ANDA  #%11011111
            STAA  PTT
            RTS
            
PORTON      LDAA  PTT                ;Set PT4 to 1 (port motor on) can find all these in lab manual
            ORAA  #%00010000
            STAA  PTT
            RTS
            
PORTOFF     LDAA  PTT                ;Set PT4 to 0 (port motor off)
            ANDA  #%11101111
            STAA  PTT
            RTS
            
STARFWD     LDAA  PORTA
            ANDA  #%11111101         ;And PA1 to 0 (starboard forward)
            STAA  PORTA
            RTS

STARREV     LDAA  PORTA
            ORAA  #%00000010         ;OR PA1 to 1 (starboard reverse)
            STAA  PORTA
            RTS

PORTFWD     LDAA  PORTA
            ANDA  #%11111110
            STAA  PORTA
            RTS

PORTREV     LDAA  PORTA
            ORAA  #%00000001
            STAA  PORTA
            RTS

;**************************************************************
;*                 Interrupt Vectors                          *
;**************************************************************
            ORG   $FFFE
            DC.W  Entry           ; Reset Vector
