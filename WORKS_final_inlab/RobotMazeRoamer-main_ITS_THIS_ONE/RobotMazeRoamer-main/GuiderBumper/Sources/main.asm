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

; Liquid Crystal Display Equates
;-------------------------------
CLEAR_HOME  EQU $01 ; Clear the display and home the cursor
INTERFACE   EQU $38 ; 8 bit interface, two line display
CURSOR_OFF  EQU $0C ; Display on, cursor off
SHIFT_OFF   EQU $06 ; Address increments, no character shift
LCD_SEC_LINE EQU 64 ; Starting addr. of 2nd line of LCD (note decimal value!)

; LCD Addresses
LCD_CNTR    EQU PTJ ; LCD Control Register: E = PJ7, RS = PJ6
LCD_DAT     EQU PORTB ; LCD Data Register: D7 = PB7, ... , D0 = PB0
LCD_E       EQU $80 ; LCD E-signal pin
LCD_RS      EQU $40 ; LCD RS-signal pin
; Other codes
NULL        EQU 00 ; The string �null terminator�
CR          EQU $0D ; �Carriage Return� character
SPACE       EQU ' ' ; The �space� character


;variable/data Section
            ORG $3800
;---------------------------------------------------------------------------
; Storage Registers (9S12C32 RAM space: $3800 ... $3FFF)
SENSOR_LINE FCB $01 ; Storage for guider sensor readings
SENSOR_BOW  FCB $23 ; Initialized to test values
SENSOR_PORT FCB $45
SENSOR_MID  FCB $67
SENSOR_STBD FCB $89

SENSOR_NUM  RMB 1 ; The currently selected sensor
 
TOP_LINE    RMB 20 ; Top line of display
            FCB NULL ; terminated by null

BOT_LINE    RMB 20 ; Bottom line of display
            FCB NULL ; terminated by null

CLEAR_LINE  FCC ' '
            FCB NULL ; terminated by null

TEMP RMB 1 ; Temporary location

;***************************************************************************************************
              ORG   $3850                   ; Where our TOF counter register lives
TOF_COUNTER   dc.b  0                       ; The timer, incremented at 23Hz
CRNT_STATE    dc.b  2                       ; Current state register
T_TURN        ds.b  1                       ; time to stop turning
TEN_THOUS     ds.b  1                       ; 10,000 digit
THOUSANDS     ds.b  1                       ; 1,000 digit
HUNDREDS      ds.b  1                       ; 100 digit
TENS          ds.b  1                       ; 10 digit
UNITS         ds.b  1                       ; 1 digit
NO_BLANK      ds.b  1                       ; Used in ?leading zero? blanking by BCD2ASC
BCD_SPARE     RMB   2






;Code Section
          ORG $4000
Entry:
_Startup:
          LDS #$4000 ; Initialize the stack pointer
          CLI ; Enable interrupts
          JSR INIT ; Initialize ports
          JSR openADC ; Initialize the ATD
          JSR openLCD ; Initialize the LCD
          JSR CLR_LCD_BUF ; Write �space� characters to the LCD buffer
          
;---------------------------------------------------------------------------
; Display Sensors


MAIN      JSR G_LEDS_ON ; Enable the guider LEDs
          JSR READ_SENSORS ; Read the 5 guider sensors
          JSR G_LEDS_OFF ; Disable the guider LEDs
          JSR DISPLAY_SENSORS ; and write them to the LCD
          LDY #6000 ; 300 ms delay to avoid
          JSR del_50us ; display artifacts
          ;LDAA #$CF             ;move LCD cursor to the 2nd row, end of msg2
          ;JSR cmd2LCD          ;"
          
;          BRCLR PORTAD0,%00000100,bowON
 ;         LDAA #$31            ;output �1� if bow sw OFF
 ;         BRA bowOFF
;bowON     LDAA #$30            ;output �0� if bow sw ON
;bowOFF    JSR putcLCD

         ; LDAA  #' ' ;output a space character in ASCII

         ; BRCLR PORTAD0,%00001000,sternON
         ; LDAA #$31           ;output �1� if stern sw OFF
         ; BRA sternOFF
;sternON   LDAA #$30           ;output �0� if stern sw ON
;sternOFF  JSR putcLCD
          
          
          BRA MAIN ; Loop forever









;Subroutine Section





;Guider Subroutines
;---------------------------------------------------------------------------
; Initialize ports
INIT    BCLR DDRAD,$FF ; Make PORTAD an input (DDRAD @ $0272)
        BSET DDRA,$FF ; Make PORTA an output (DDRA @ $0002)
        BSET DDRB,$FF ; Make PORTB an output (DDRB @ $0003)
        BSET DDRJ,$C0 ; Make pins 7,6 of PTJ outputs (DDRJ @ $026A)
        RTS

;---------------------------------------------------------------------------
; Initialize the ADC
openADC MOVB #$80,ATDCTL2 ; Turn on ADC (ATDCTL2 @ $0082)
        LDY #1 ; Wait for 50 us for ADC to be ready
        JSR del_50us ; - " -
        MOVB #$20,ATDCTL3 ; 4 conversions on channel AN1 (ATDCTL3 @ $0083)
        MOVB #$97,ATDCTL4 ; 8-bit resolution, prescaler=48 (ATDCTL4 @ $0084)
        RTS


 ;---------------------------------------------------------------------------
; Clear LCD Buffer
; This routine writes �space� characters (ascii 20) into the LCD display
; buffer in order to prepare it for the building of a new display buffer.
; This needs only to be done once at the start of the program. Thereafter the
; display routine should maintain the buffer properly.
CLR_LCD_BUF LDX #CLEAR_LINE
            LDY #TOP_LINE
            JSR STRCPY

CLB_SECOND  LDX #CLEAR_LINE
            LDY #BOT_LINE
            JSR STRCPY

CLB_EXIT    RTS



;---------------------------------------------------------------------------
; String Copy

; Copies a null-terminated string (including the null) from one location to
; another

; Passed: X contains starting address of null-terminated string
; Y contains first address of destination
STRCPY      PSHX ; Protect the registers used
            PSHY
            PSHA
STRCPY_LOOP LDAA 0,X ; Get a source character
            STAA 0,Y ; Copy it to the destination
            BEQ STRCPY_EXIT ; If it was the null, then exit
            INX ; Else increment the pointers
            INY
            BRA STRCPY_LOOP ; and do it again
STRCPY_EXIT PULA ; Restore the registers
            PULY
            PULX
            RTS





;---------------------------------------------------------------------------
; Guider LEDs ON
; This routine enables the guider LEDs so that readings of the sensor
; correspond to the �illuminated� situation.
; Passed: Nothing
; Returns: Nothing
; Side: PORTA bit 5 is changed

G_LEDS_ON   BSET PORTA,%00100000 ; Set bit 5
            RTS
;
; Guider LEDs OFF
; This routine disables the guider LEDs. Readings of the sensor
; correspond to the �ambient lighting� situation.

; Passed: Nothing
; Returns: Nothing
; Side: PORTA bit 5 is changed

G_LEDS_OFF BCLR PORTA,%00100000 ; Clear bit 5
           RTS


;---------------------------------------------------------------------------
; Read Sensors
;
; This routine reads the eebot guider sensors and puts the results in RAM
; registers.
; Note: Do not confuse the analog multiplexer on the Guider board with the
; multiplexer in the HCS12. The guider board mux must be set to the
; appropriate channel using the SELECT_SENSOR routine. The HCS12 always
; reads the selected sensor on the HCS12 A/D channel AN1.
; The A/D conversion mode used in this routine is to read the A/D channel
; AN1 four times into HCS12 data registers ATDDR0,1,2,3. The only result
; used in this routine is the value from AN1, read from ATDDR0. However,
; other routines may wish to use the results in ATDDR1, 2 and 3.
; Consequently, Scan=0, Mult=0 and Channel=001 for the ATDCTL5 control word.
; Passed: None
; Returns: Sensor readings in:
; SENSOR_LINE (0) (Sensor E/F)
; SENSOR_BOW (1) (Sensor A)
; SENSOR_PORT (2) (Sensor B)
; SENSOR_MID (3) (Sensor C)
; SENSOR_STBD (4) (Sensor D)
; Note:
; The sensor number is shown in brackets
;
; Algorithm:
;       Initialize the sensor number to 0
;       Initialize a pointer into the RAM at the start of the Sensor Array storage
; Loop  Store %10000001 to the ATDCTL5 (to select AN1 and start a conversion)
;       Repeat
;         Read ATDSTAT0
;       Until Bit SCF of ATDSTAT0 == 1 (at which time the conversion is complete)
;       Store the contents of ATDDR0L at the pointer
;       If the pointer is at the last entry in Sensor Array, then
;         Exit
;       Else
;         Increment the sensor number
;         Increment the pointer
;       Loop again.
READ_SENSORS  CLR SENSOR_NUM ; Select sensor number 0
              LDX #SENSOR_LINE ; Point at the start of the sensor array

RS_MAIN_LOOP  LDAA SENSOR_NUM ; Select the correct sensor input
              JSR SELECT_SENSOR ; on the hardware
              LDY #400 ; 20 ms delay to allow the
              JSR del_50us ; sensor to stabilize
              
              LDAA #%10000001 ; Start A/D conversion on AN1
              STAA ATDCTL5
              BRCLR ATDSTAT0,$80,* ; Repeat until A/D signals done
              
              LDAA ATDDR0L ; A/D conversion is complete in ATDDR0L
              STAA 0,X ; so copy it to the sensor register
              CPX #SENSOR_STBD ; If this is the last reading
              BEQ RS_EXIT ; Then exit
              
              INC SENSOR_NUM ; Else, increment the sensor number
              INX ; and the pointer into the sensor array
              BRA RS_MAIN_LOOP ; and do it again
RS_EXIT       RTS


;---------------------------------------------------------------------------
; Select Sensor
; This routine selects the sensor number passed in ACCA. The motor direction
; bits 0, 1, the guider sensor select bit 5 and the unused bits 6,7 in the
; same machine register PORTA are not affected.
; Bits PA2,PA3,PA4 are connected to a 74HC4051 analog mux on the guider board,
; which selects the guider sensor to be connected to AN1.
; Passed: Sensor Number in ACCA
; Returns: Nothing
; Side Effects: ACCA is changed
; Algorithm:
; First, copy the contents of PORTA into a temporary location TEMP and clear
; the sensor bits 2,3,4 in the TEMP to zeros by ANDing it with the mask
; 11100011. The zeros in the mask clear the corresponding bits in the
; TEMP. The 1�s have no effect.
; Next, move the sensor selection number left two positions to align it
; with the correct bit positions for sensor selection.
; Clear all the bits around the (shifted) sensor number by ANDing it with
; the mask 00011100. The zeros in the mask clear everything except
; the sensor number.
; Now we can combine the sensor number with the TEMP using logical OR.
; The effect is that only bits 2,3,4 are changed in the TEMP, and these
; bits now correspond to the sensor number.
; Finally, save the TEMP to the hardware.

SELECT_SENSOR PSHA ; Save the sensor number for the moment
              
              LDAA PORTA ; Clear the sensor selection bits to zeros
              ANDA #%11100011 ;
              STAA TEMP ; and save it into TEMP

              PULA ; Get the sensor number
              ASLA ; Shift the selection number left, twice
              ASLA ;
              ANDA #%00011100 ; Clear irrelevant bit positions

              ORAA TEMP ; OR it into the sensor bit positions
              STAA PORTA ; Update the hardware
              RTS


;---------------------------------------------------------------------------
; Display Sensor Readings
; Passed: Sensor values in RAM locations SENSOR_LINE through SENSOR_STBD.
; Returns: Nothing
; Side: Everything
; This routine writes the sensor values to the LCD. It uses the �shadow buffer� approach.
; The display buffer is built by the display controller routine and then copied in its
; entirety to the actual LCD display. Although simpler approaches will work in this
; application, we take that approach to make the code more re-useable.
; It�s important that the display controller not write over other information on the
; LCD, so writing the LCD has to be centralized with a controller routine like this one.
; In a more complex program with additional things to display on the LCD, this routine
; would be extended to read other variables and place them on the LCD. It might even
; read some �display select� variable to determine what should be on the LCD.
; For the purposes of this routine, we�ll put the sensor values on the LCD
; in such a way that they (sort of) mimic the position of the sensors, so
; the display looks like this:
; 01234567890123456789
; ___FF_______________
; PP_MM_SS_LL_________

; Where FF is the front sensor, PP is port, MM is mid, SS is starboard and
; LL is the line sensor.

; The corresponding addresses in the LCD buffer are defined in the following
; equates (In all cases, the display position is the MSDigit).

DP_FRONT_SENSOR   EQU TOP_LINE+3
DP_PORT_SENSOR    EQU BOT_LINE+0
DP_MID_SENSOR     EQU BOT_LINE+3
DP_STBD_SENSOR    EQU BOT_LINE+6
DP_LINE_SENSOR    EQU BOT_LINE+9

DISPLAY_SENSORS   LDAA SENSOR_BOW ; Get the FRONT sensor value
                  JSR BIN2ASC ; Convert to ascii string in D
                  LDX #DP_FRONT_SENSOR ; Point to the LCD buffer position
                  STD 0,X ; and write the 2 ascii digits there
                  
                  LDAA SENSOR_PORT ; Repeat for the PORT value
                  JSR BIN2ASC
                  LDX #DP_PORT_SENSOR
                  STD 0,X
                  
                  LDAA SENSOR_MID ; Repeat for the MID value
                  JSR BIN2ASC
                  LDX #DP_MID_SENSOR
                  STD 0,X
                  
                  LDAA SENSOR_STBD ; Repeat for the STARBOARD value
                  JSR BIN2ASC
                  LDX #DP_STBD_SENSOR
                  STD 0,X
                  
                  LDAA SENSOR_LINE ; Repeat for the LINE value
                  JSR BIN2ASC
                  LDX #DP_LINE_SENSOR
                  STD 0,X
                  
                  LDAA #CLEAR_HOME ; Clear the display and home the cursor
                  JSR cmd2LCD ; "
                  LDY #40 ; Wait 2 ms until "clear display" command is complete
                  JSR del_50us
                  
                  LDX #TOP_LINE ; Now copy the buffer top line to the LCD
                  JSR putsLCD
                  
                  LDAA #LCD_SEC_LINE ; Position the LCD cursor on the second line
                  JSR LCD_POS_CRSR
                  LDX #BOT_LINE ; Copy the buffer bottom line to the LCD
                  JSR putsLCD
                  RTS

;Timer Overflow Flag
;***************************************************************************************************
ENABLE_TOF        LDAA    #%10000000
                  STAA    TSCR1           ; Enable TCNT
                  STAA    TFLG2           ; Clear TOF
                  LDAA    #%10000100      ; Enable TOI and select prescale factor equal to 16
                  STAA    TSCR2
                  RTS

TOF_ISR           INC     TOF_COUNTER
                  LDAA    #%10000000      ; Clear
                  STAA    TFLG2           ; TOF
                  RTI


;---------------------------------------------------------------------------
; Routines to control the Liquid Crystal Display
;---------------------------------------------------------------------------
; Initialize the LCD
;*******************************************************************
openLCD LDY #2000 ; Wait 100 ms for LCD to be ready
        JSR del_50us ; "
        LDAA #INTERFACE ; Set 8-bit data, 2-line display, 5x8 font
        JSR cmd2LCD ; "
        LDAA #CURSOR_OFF ; Display on, cursor off, blinking off
        JSR cmd2LCD ; "
        LDAA #SHIFT_OFF ; Move cursor right (address increments, no char. shift)
        JSR cmd2LCD ; "
        LDAA #CLEAR_HOME ; Clear the display and home the cursor
        JSR cmd2LCD ; "
        LDY #40 ; Wait 2 ms until "clear display" command is complete
        JSR del_50us ; "
        RTS


;*****************************************************************
clrLCD     LDAA  #$01                      ; clear cursor and return to home positions
           JSR   cmd2LCD                   ;     -"-
           LDY   #40                       ;wait until "clear cursor" command is complete
           JSR   del_50us                  ;     -"-
           RTS

;*******************************************************************
del_50us   PSHX ; (2 E-clk) Protect the X register
eloop      LDX #300 ; (2 E-clk) Initialize the inner loop counter
iloop      NOP ; (1 E-clk) No operation
           DBNE X,iloop ; (3 E-clk) If the inner cntr not 0, loop again
           DBNE Y,eloop ; (3 E-clk) If the outer cntr not 0, loop again
           PULX ; (3 E-clk) Restore the X register
           RTS             

;*****************************************************************
cmd2LCD:    BCLR  LCD_CNTR, LCD_RS          ; select the LCD Instruction Register(IR)
            JSR   dataMov                   ; send data to the IR   
            RTS

;*******************************************************************
putsLCD       LDAA  1,X+                      ; get one character from the string
              BEQ   donePS                    ; reach NULL character?
              JSR   putcLCD
              BRA   putsLCD
donePS        RTS

;*****************************************************************
putcLCD     BSET    LCD_CNTR, LCD_RS        ; select the LCD Data register(DR)
            JSR     dataMov                 ; send data to DR
            RTS
 
;*****************************************************************
dataMov     BSET    LCD_CNTR, LCD_E         ; pull the LCD E-signal high
            STAA    LCD_DAT                 ; send the upper 4 bits of data to LCD
            BCLR    LCD_CNTR, LCD_E         ; pull the LCD E-signal low to complete the write oper.
              
            LSLA                            ; match the lower 4 bits with the LCD data pins
            LSLA
            LSLA
            LSLA
              
            BSET    LCD_CNTR, LCD_E         ; pull the LCD E-signal low to complete the write oper.  
            STAA    LCD_DAT                 ; send the lower 4 bits of data to LCD
            BCLR    LCD_CNTR, LCD_E         ; pull the LCD E-signla low to complete the write oper.
              
            LDY     #1                      ; adding this delay will complete the internal
            JSR     del_50us                ; operation of most instructions
            RTS
            
            
;---------------------------------------------------------------------------
; Position the Cursor
; This routine positions the display cursor in preparation for the writing
; of a character or string.
; For a 20x2 display:
; The first line of the display runs from 0 .. 19.
; The second line runs from 64 .. 83.
; The control instruction to position the cursor has the format
; 1aaaaaaa
; where aaaaaaa is a 7 bit address.
; Passed: 7 bit cursor Address in ACCA
; Returns: Nothing
; Side Effects: None
LCD_POS_CRSR ORAA #%10000000 ; Set the high bit of the control word
             JSR cmd2LCD ; and set the cursor address
             RTS


;****************************************************************
initAD     MOVB #$C0,ATDCTL2             ;power up AD, select fast flag clear
           JSR del_50us                  ;wait for 50 us
           MOVB #$00,ATDCTL3             ;8 conversions in a sequence
           MOVB #$85,ATDCTL4             ;res=8, conv-clks=2, prescal=12
           BSET ATDDIEN,$0C              ;configure pins AN03,AN02 as digital inputs
           RTS




;Conversion Routine
;---------------------------------------------------------------------------
; Binary to ASCII
; Converts an 8 bit binary value in ACCA to the equivalent ASCII character 2
; character string in accumulator D
; Uses a table-driven method rather than various tricks.
; Passed: Binary value in ACCA
; Returns: ASCII Character string in D
; Side Fx: ACCB is destroyed

HEX_TABLE   FCC '0123456789ABCDEF' ; Table for converting values

BIN2ASC     PSHA ; Save a copy of the input number on the stack
            TAB ; and copy it into ACCB
            ANDB #%00001111 ; Strip off the upper nibble of ACCB
            CLRA ; D now contains 000n where n is the LSnibble
            ADDD #HEX_TABLE ; Set up for indexed load
            XGDX
            LDAA 0,X ; Get the LSnibble character
            PULB ; Retrieve the input number into ACCB
            PSHA ; and push the LSnibble character in its place
            RORB ; Move the upper nibble of the input number
            RORB ; into the lower nibble position.
            RORB
            RORB
            ANDB #%00001111 ; Strip off the upper nibble
            CLRA ; D now contains 000n where n is the MSnibble
            ADDD #HEX_TABLE ; Set up for indexed load
            XGDX
            LDAA 0,X ; Get the MSnibble character into ACCA
            PULB ; Retrieve the LSnibble character into ACCB



;***************************************************************
INT2BCD    XGDX                          ;Save the binary number into .X
           LDAA #0                       ;Clear the BCD_BUFFER
           STAA TEN_THOUS
           STAA THOUSANDS
           STAA HUNDREDS
           STAA TENS
           STAA UNITS
           STAA BCD_SPARE
           STAA BCD_SPARE+1
;*
           CPX #0                        ;Check for a zero input
           BEQ CON_EXIT                  ;and if so, exit
;*
           XGDX                          ;Not zero, get the binary number back to .D as dividend
           LDX #10                       ;Setup 10 (Decimal!) as the divisor
           IDIV                          ;Divide: Quotient is now in .X, remainder in .D
           STAB UNITS                    ;Store remainder
           CPX #0                        ;If quotient is zero,
           BEQ CON_EXIT                  ;then exit
;*
           XGDX                          ;else swap first quotient back into .D
           LDX #10                       ;and setup for another divide by 10
           IDIV
           STAB TENS
           CPX #0
           BEQ CON_EXIT
;*
           XGDX                          ;Swap quotient back into .D
           LDX #10                       ;and setup for another divide by 10
           IDIV
           STAB HUNDREDS
           CPX #0
           BEQ CON_EXIT
;*
           XGDX                          ;Swap quotient back into .D
           LDX #10                       ;and setup for another divide by 10
           IDIV
           STAB THOUSANDS
           CPX #0
           BEQ CON_EXIT
*
           XGDX                          ;Swap quotient back into .D
           LDX #10                       ;and setup for another divide by 10
           IDIV
           STAB TEN_THOUS
*
CON_EXIT   RTS  

;****************************************************************                                                             
BCD2ASC    LDAA #0                       ;Initialize the blanking flag
           STAA NO_BLANK
;*
C_TTHOU    LDAA TEN_THOUS                ;Check the �ten_thousands� digit
           ORAA NO_BLANK
           BNE NOT_BLANK1
;*
ISBLANK1   LDAA #' '                     ;It�s blank
           STAA TEN_THOUS                ;so store a space
           BRA C_THOU                    ;and check the �thousands� digit
;*
NOT_BLANK1 LDAA TEN_THOUS                ;Get the �ten_thousands� digit
           ORAA #$30                     ;Convert to ascii
           STAA TEN_THOUS
           LDAA #$1                      ;Signal that we have seen a �non-blank� digit
           STAA NO_BLANK
;*
C_THOU     LDAA THOUSANDS                ;Check the thousands digit for blankness
           ORAA NO_BLANK                 ;If it�s blank and �no-blank� is still zero
           BNE NOT_BLANK2
;*
ISBLANK2   LDAA #' '                     ;Thousands digit is blank
           STAA THOUSANDS                ;so store a space
           BRA C_HUNS                    ;and check the hundreds digit
;*
NOT_BLANK2 LDAA THOUSANDS                ;(similar to �ten_thousands� case)
           ORAA #$30
           STAA THOUSANDS
           LDAA #$1
           STAA NO_BLANK
;*
C_HUNS     LDAA HUNDREDS                 ;Check the hundreds digit for blankness
           ORAA NO_BLANK                 ;If it�s blank and �no-blank� is still zero
           BNE NOT_BLANK3
;*
ISBLANK3   LDAA #' '                     ;Hundreds digit is blank
           STAA HUNDREDS                 ;so store a space
           BRA C_TENS                    ;and check the tens digit
;*
NOT_BLANK3 LDAA HUNDREDS                 ;(similar to �ten_thousands� case)
           ORAA #$30
           STAA HUNDREDS
           LDAA #$1
           STAA NO_BLANK
;*
C_TENS     LDAA TENS                     ;Check the tens digit for blankness
           ORAA NO_BLANK                 ;If it�s blank and �no-blank� is still zero
           BNE NOT_BLANK4
;*
ISBLANK4   LDAA #' '                     ;Tens digit is blank
           STAA TENS                     ;so store a space
           BRA C_UNITS                   ;and check the units digit
;*
NOT_BLANK4 LDAA TENS                     ;(similar to �ten_thousands� case)
           ORAA #$30      
           STAA TENS
;*
C_UNITS    LDAA UNITS                    ;No blank check necessary, convert to ascii.
           ORAA #$30
           STAA UNITS
;*
           RTS ;We�re done




;**************************************************************
;*                 Interrupt Vectors                          *
;**************************************************************
            ORG   $FFFE
            DC.W  Entry           ; Reset Vector

            ORG $FFDE
            DC.W TOF_ISR          ; Timer Overflow Interrupt Vector