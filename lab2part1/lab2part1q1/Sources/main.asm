;*****************************************************************
;* This stationery serves as the framework for a                 *
;* user application (single file, absolute assembly application) *
;* For a more comprehensive program that                         *
;* demonstrates the more advanced functionality of this          *
;* processor, please see the demonstration applications          *
;* located in the examples subdirectory of the                   *
;* Raymond Cao Jiang, 501183087                                  *
;*****************************************************************

; export symbols
            XDEF Entry, _Startup            ; export 'Entry' symbol
            ABSENTRY Entry        ; for absolute assembly: mark this as application entry point



; Include derivative-specific definitions 
		INCLUDE 'derivative.inc' 

; code section
            ORG   $4000


Entry:
_Startup:
; 1 making sure the led on board turns on based on input 

            LDAA    #$FF  ; ACCA = $FF  %1111 1111 (# to specify an exact number to be used at this moment)
            STAA    DDRH  ; Config. Port H for output
            STAA    PERT  ; Enab. pull-up res. of Port T
      Loop: LDAA    PTT   ; Read Port T
            STAA    PTH   ; Display SW1 on LED1 connected to Port H
            BRA     Loop  ; Loop

;**************************************************************
;*                 Interrupt Vectors                          *
;**************************************************************
            ORG   $FFFE
            DC.W  Entry           ; Reset Vector


