;*****************************************************************
;* This stationery serves as the framework for a                 *
;* user application (single file, absolute assembly application) *
;* For a more comprehensive program that                         *
;* demonstrates the more advanced functionality of this          *
;* processor, please see the demonstration applications          *
;* located in the examples subdirectory of the                   *
;* Raymond Cao Jiang, 501183087                                  *
;*****************************************************************

;export symbol
           XDEF Entry, _Startup
           ABSENTRY Entry
;Include derivative-specific definitions
            INCLUDE 'derivative.inc'           

; Definitions
 
LCD_DAT      EQU PTS     ; LCD data port S, pins PS7,PS6,PS5,PS4
LCD_CNTR     EQU PORTE   ; LCD control port E, pins PE7(RS),PE4(E)
LCD_E        EQU $10     ; LCD enable signal, pin PE4
LCD_RS       EQU $80     ; LCD reset signal, pin PE7

; code section

;variable section
 
               ORG $3000
Hex1         FCB $30  ;store hex value $30 and $87    
Hex2         FCB $87     

MEM1         RMB 01 ;reserve memory for ASCII byte
MEM2         RMB 01
MEM3         RMB 01
MEM4         RMB 01
MEM5         RMB 01 ;reserve memory for termination char null

               ORG $4000
Entry:

_Startup:

               LDS #$4000  ; initialize stack pointer
               JSR initLCD ; initialize LCD
;*******************************************************************
;* Program starts here                                             *
;*******************************************************************
MainLoop       JSR clrLCD       ; clear LCD & home cursor
               LDX #msg1        ; display msg1
               JSR putsLCD      ; -"-
               LDAA $3000       ; load contents at $3000 into A
               JSR leftHLF      ; convert left half of A into ASCII
               STAA MEM1        ; store the ASCII byte into mem1
               LDAA $3000       ; load contents at $3000 into A
               JSR rightHLF     ; convert right half of A into ASCII
               STAA MEM2        ; store the ASCII byte into mem2
               LDAA $3001       ; load contents at $3001 into A
               JSR leftHLF      ; convert left half of A into ASCII
               STAA MEM3        ; store the ASCII byte into mem3
               LDAA $3001       ; load contents at $3001 into A
               JSR rightHLF     ; convert right half of A into ASCII               
               STAA MEM4        ; store the ASCII byte into mem4
               LDAA 0           ; load 0 (null) into A
               STAA MEM5        ; store string termination character 00 into mem5
               LDX #MEM1        ; output the 4 ASCII characters
               JSR putsLCD      ; -"- stops sending data to LCD after null
               LDY #20000       ; Delay = 1s  20,000 is the amount of times you call the subroutine, LCD takes time to process
               JSR del_50us
               BRA MainLoop     ; Loop
msg1           dc.b "Hi there! ",0
;subroutine section
;*******************************************************************
;* Initialization of the LCD: 4-bit data width, 2-line display,    *
;* turn on display, cursor and blinking off. Shift cursor right.   *
;*******************************************************************
initLCD        BSET DDRS,%11110000 ; configure pins PS7,PS6,PS5,PS4 for output
               BSET DDRE,%10010000      ; configure pins PE7,PE4 for output
               LDY #2000           ; wait for LCD to be ready
               JSR del_50us        ; -"- delay
               LDAA #$28           ; set 4-bit data, 2-line display
               JSR cmd2LCD         ; -"- send command to LCD
               LDAA #$0C           ; display on, cursor off, blinking off
               JSR cmd2LCD         ; -"- send comman to LCD
               LDAA #$06           ; move cursor right after entering a character
               JSR cmd2LCD         ; -"- send command to LCD
               RTS
;*******************************************************************
;* Clear display and home cursor                                   *
;*******************************************************************
clrLCD         LDAA #$01           ; clear cursor and return to home position
               JSR cmd2LCD         ; -"- send command to LCD
               LDY #40             ; wait until "clear cursor" command is complete
               JSR del_50us        ; -"- delay
               RTS
;*******************************************************************
;* ([Y] x 50us)-delay subroutine. E-clk=41,67ns.                   *
;*******************************************************************
del_50us:      PSHX                ;2 E-clk
eloop:         LDX #30             ;2 E-clk -
iloop:         PSHA                ;2 E-clk |
               PULA                ;3 E-clk |
               PSHA
               PULA
               PSHA
               PULA
               PSHA
               PULA
               PSHA
               PULA              
               PSHA                ;2 E-clk | 50us
               PULA                ;3 E-clk |
               NOP                 ;1 E-clk |
               NOP                 ;1 E-clk |
               DBNE X,iloop        ;3 E-clk -
               DBNE Y,eloop        ;3 E-clk
               PULX                ;3 E-clk
               RTS                 ;5 E-clk
;*******************************************************************
;* This function sends a command in accumulator A to the LCD       *
;*******************************************************************
cmd2LCD:       BCLR LCD_CNTR,LCD_RS ; select the LCD Instruction Register (IR)
               JSR dataMov          ; send data to IR
               RTS
;*******************************************************************
;* This function outputs a NULL-terminated string pointed to by X  *
;*******************************************************************
putsLCD        LDAA 1,X+           ; get one character from the string
               BEQ donePS          ; reach NULL character?
               JSR putcLCD
               BRA putsLCD
donePS         RTS
;*******************************************************************
;* This function outputs the character in accumulator in A to LCD  *
;*******************************************************************
putcLCD        BSET LCD_CNTR,LCD_RS ; select the LCD Data register (DR)
               JSR dataMov          ; send data to DR
               RTS
;*******************************************************************
;* This function sends data to the LCD IR or DR depening on RS     *
;*******************************************************************
dataMov        BSET LCD_CNTR,LCD_E  ; pull the LCD E-sigal high
               STAA LCD_DAT         ; send the upper 4 bits of data to LCD
               BCLR LCD_CNTR,LCD_E  ; pull the LCD E-signal low to complete the write oper.
               LSLA                 ; match the lower 4 bits with the LCD data pins
               LSLA                 ; -"-
               LSLA                 ; -"-
               LSLA                 ; -"-
               BSET LCD_CNTR,LCD_E  ; pull the LCD E signal high
               STAA LCD_DAT         ; send the lower 4 bits of data to LCD
               BCLR LCD_CNTR,LCD_E  ; pull the LCD E-signal low to complete the write oper.
               LDY #1               ; adding this delay will complete the internal
               JSR del_50us         ; operation for most instructions
               RTS
;*******************************************************************
;* Binary to ASCII                                                 *
;*******************************************************************
leftHLF        LSRA ; shift data to right 4 times to get left half
               LSRA
               LSRA
               LSRA
rightHLF       ANDA #$0F ; mask top half by ANDing with 0F(00001111) leaving lower 4 bits
               ADDA #$30 ; convert to ascii by adding 0x30 (48 in decimal)
               CMPA #$39 ; compares acca wtih hexa 39(9 ASCII)
               BLE out ; jump if 0-9 (A<=9)
               ADDA #$07 ; convert to hex A-F if greater than 9
out            RTS

