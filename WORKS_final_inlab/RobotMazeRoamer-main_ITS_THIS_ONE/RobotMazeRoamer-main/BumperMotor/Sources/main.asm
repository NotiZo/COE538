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

TARGET      FCB 68
MARGIN      EQU 5
LEFT_T      EQU 8
RIGHT_T     EQU 8

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
NO_BLANK      ds.b  1                       ; Used in 'leading zero' blanking by BCD2ASC
BCD_SPARE     RMB   2
CRN_DIR       ds.b  1
OPP_DIR       ds.b  1

START         EQU   0
FWD           EQU   1
ALL_STP       EQU   2
LEFT_TRN      EQU   3
RIGHT_TRN     EQU   4
REV           EQU   5
               


NORTH         EQU   0
EAST          EQU   1
SOUTH         EQU   2
WEST          EQU   3

;Code Section
Entry:                                                                       
_Startup: 

              LDS   #$4000                 ; Initialize the stack pointer
              CLI                          ; Enable interrupts
              JSR   INIT                   ; Initialize ports
              JSR   openADC                ; Initialize the ATD
              JSR   initLCD                ; Initialize the LCD
              JSR   CLR_LCD_BUF            ; Write ?space? characters to the LCD buffer 
              BSET  DDRA,%00000011         ; STAR_DIR, PORT_DIR                        
              BSET  DDRT,%00110000         ; STAR_SPEED, PORT_SPEED                    
              JSR   initAD                 ; Initialize ATD converter                  
              JSR   initLCD                ; Initialize the LCD                        
              JSR   clrLCD                 ; Clear LCD & home cursor                   
              LDX   #msg1                  ; Display msg1                              
              JSR   putsLCD                ;       "                                   
              LDAA  #$C0                   ; Move LCD cursor to the 2nd row           
              JSR   cmd2LCD                ;                                           
              LDX   #msg2                  ; Display msg2                              
              JSR   putsLCD                ;       "      
              JSR   ENABLE_TOF             ; Jump to TOF initialization

;---------------------------------------------------------------------------
; Display Sensors


MAIN      JSR G_LEDS_ON ; Enable the guider LEDs
          JSR READ_SENSORS ; Read the 5 guider sensors
          JSR G_LEDS_OFF ; Disable the guider LEDs
          JSR UPDT_DISPL
          JSR DISPATCHER
          BRA MAIN

;Constants section
msg1          dc.b  "Battery volt ",0
msg2          dc.b  "State",0
tab           dc.b  "start  ",0
              dc.b  "fwd    ",0
              dc.b  "all_stp",0
              dc.b  "LeftTurn  ",0
              dc.b  "RightTurn  ",0
              dc.b  "RevTrn ",0
              dc.b  "LeftTimed ",0     
              dc.b  "RTimed ",0  



;Subroutine Section
DISPATCHER    CMPA  #START                    ; If it�s the START state -----------------
              BNE   NOT_START                 ;                                           |
              JSR   START_ST                  ; then call START_ST routine                D
              BRA   DISP_EXIT                 ; and exit                                  I
                                              ; **Refer to page 8**                       S
NOT_START     CMPA  #FWD                      ; **Else if it's the FORWARD state          P
              BNE   NOT_FWD                   ;                                           A
              JSR   FWD_ST                    ; **then call the FORWARD routine
              JMP   DISP_EXIT                 ; **and exit
              
NOT_FWD       CMPA  #REV                      ; **Else if it's the REVERSE state
              BNE   NOT_REV
              JSR   INIT_TRN_ARND                    ; **then call the REVERSE routine
              JMP   DISP_EXIT                 ; and exit
              
NOT_REV       CMPA  #ALL_STP                  ; **Else if it's the ALL_STOP state
              BNE   NOT_ALL_STP
              JSR   ALL_STP_ST                ; **then call the ALL_STOP routine
              BRA   DISP_EXIT                 ; and exit
              
NOT_ALL_STP   SWI     
DISP_EXIT     RTS   

;Motor Control Intialization Subroutines
;*******************************************************************
START_ST    BRCLR PORTAD0, $04, NO_FWD
            JSR   FWD_ST
            MOVB  #FWD, CRNT_STATE
            BRA START_EXIT
           
NO_FWD      NOP
START_EXIT  RTS
;*******************************************************************
FWD_ST      BRSET PORTAD0,$04,NO_FWD_BUMP ; If FWD_BUMP then
            JSR INIT_TRN_ARND ; initialize the REVERSE routine
            MOVB #REV,CRNT_STATE ; set the state to REVERSE
            JMP FWD_EXIT ; and return
            
NO_FWD_BUMP BRSET PORTAD0,$08,LINE_FOLLOWER ; If REAR_BUMP, then we should stop
            JSR ALL_STP_ST ; so initialize the ALL_STOP state
            MOVB #ALL_STP,CRNT_STATE ; and change state to ALL_STOP
            JMP FWD_EXIT ; and return
            
LINE_FOLLOWER JSR READ_SENSORS
              LDAA SENSOR_LINE
              SUBA TARGET
              CMPA MARGIN
              BLS FWD_ST
              
              LDAA SENSOR_LINE
              SUBA TARGET
              BPL IS_STARBOARD
              BMI IS_PORT
              
              
IS_STARBOARD  BCLR PORTA, %00000001
              BSET PORTA, %00000010
              BRA LINE_FOLLOWER


IS_PORT       BCLR PORTA, %00000010
              BSET PORTA, %00000001
              BRA LINE_FOLLOWER
 
            

FWD_EXIT    RTS ; Return to the MAIN routine.

;*******************************************************************
ALL_STP_ST  BRSET PORTAD0,$04,NO_START ; If FWD_BUMP
            BCLR PTT,%00110000 ; initialize the START state (both motors off)
            MOVB #START,CRNT_STATE ; set the state to START
            BRA ALL_STP_EXIT ; and return
NO_START    NOP ; Else
ALL_STP_EXIT RTS ; return to the MAIN routine            
            

; Initialization Subroutines
;***************************************************************************************************
INIT_RIGHT        BSET    PORTA,%00000010          
                  BCLR    PORTA,%00000001           
                  LDAA    TOF_COUNTER               ; Mark the fwd_turn time Tfwdturn
                  ADDA    #RIGHT_T
                  STAA    T_TURN
                  RTS

INIT_LEFT         BSET    PORTA,%00000001         
                  BCLR    PORTA,%00000010          
                  LDAA    TOF_COUNTER               ; Mark TOF time
                  ADDA    #LEFT_T                   ; Add left turn
                  STAA    T_TURN                    
                  RTS

INIT_FWD          BCLR    PORTA, %00000011          ; Set FWD dir. for both motors
                  BSET    PTT, %00110000            ; Turn on the drive motors
                  RTS 

INIT_REV          BSET PORTA,%00000011              ; Set REV direction for both motors
                  BSET PTT,%00110000                ; Turn on the drive motors
                  RTS

INIT_STOP         BCLR    PTT, %00110000            ; Turn off the drive motors
                  RTS

INIT_TRN_ARND     JSR INIT_LEFT
                  JSR INIT_LEFT
                  RTS

;***************************************************************************************************
;       Initialize Sensors
INIT              BCLR   DDRAD,$FF ; Make PORTAD an input (DDRAD @ $0272)
                  BSET   DDRA,$FF  ; Make PORTA an output (DDRA @ $0002)
                  BSET   DDRB,$FF  ; Make PORTB an output (DDRB @ $0003)
                  BSET   DDRJ,$C0  ; Make pins 7,6 of PTJ outputs (DDRJ @ $026A)
                  RTS


;***************************************************************************************************
;        Initialize ADC              
openADC           MOVB   #$80,ATDCTL2 ; Turn on ADC (ATDCTL2 @ $0082)
                  LDY    #1           ; Wait for 50 us for ADC to be ready
                  JSR    del_50us     ; - " -
                  MOVB   #$20,ATDCTL3 ; 4 conversions on channel AN1 (ATDCTL3 @ $0083)
                  MOVB   #$97,ATDCTL4 ; 8-bit resolution, prescaler=48 (ATDCTL4 @ $0084)
                  RTS

;---------------------------------------------------------------------------
;                           Clear LCD Buffer
; This routine writes ?space? characters (ascii 20) into the LCD display
; buffer in order to prepare it for the building of a new display buffer.
; This needs only to be done once at the start of the program. Thereafter the
; display routine should maintain the buffer properly.
CLR_LCD_BUF       LDX   #CLEAR_LINE
                  LDY   #TOP_LINE
                  JSR   STRCPY

CLB_SECOND        LDX   #CLEAR_LINE
                  LDY   #BOT_LINE
                  JSR   STRCPY

CLB_EXIT          RTS

; -------------------------------------------------------------------------------------------------      
; String Copy
; Copies a null-terminated string (including the null) from one location to
; another
; Passed: X contains starting address of null-terminated string
; Y contains first address of destination
STRCPY            PSHX            ; Protect the registers used
                  PSHY
                  PSHA

STRCPY_LOOP       LDAA 0,X        ; Get a source character
                  STAA 0,Y        ; Copy it to the destination
                  BEQ STRCPY_EXIT ; If it was the null, then exit
                  INX             ; Else increment the pointers
                  INY
                  BRA STRCPY_LOOP ; and do it again

STRCPY_EXIT       PULA            ; Restore the registers
                  PULY
                  PULX
                  RTS  

; -------------------------------------------------------------------------------------------------      
;                                   Guider LEDs ON                                                 |
; This routine enables the guider LEDs so that readings of the sensor                              |
; correspond to the ?illuminated? situation.                                                       |
; Passed: Nothing                                                                                  |
; Returns: Nothing                                                                                 |
; Side: PORTA bit 5 is changed                                                                     |
G_LEDS_ON         BSET PORTA,%00100000 ; Set bit 5                                                 |
                  RTS                                                                             ;|

; -------------------------------------------------------------------------------------------------      
;                                   Guider LEDs OFF                                                |
; This routine disables the guider LEDs. Readings of the sensor                                    |
; correspond to the ?ambient lighting? situation.                                                  |
; Passed: Nothing                                                                                  |
; Returns: Nothing                                                                                 |
; Side: PORTA bit 5 is changed                                                                     |
G_LEDS_OFF        BCLR PORTA,%00100000 ; Clear bit 5                                               |
                  RTS                                                                             ;|    

; -------------------------------------------------------------------------------------------------      
;                               Read Sensors

READ_SENSORS      CLR   SENSOR_NUM     ; Select sensor number 0
                  LDX   #SENSOR_LINE   ; Point at the start of the sensor array

RS_MAIN_LOOP      LDAA  SENSOR_NUM     ; Select the correct sensor input
                  JSR   SELECT_SENSOR  ; on the hardware
                  LDY   #400           ; 20 ms delay to allow the
                  JSR   del_50us       ; sensor to stabilize
                  LDAA  #%10000001     ; Start A/D conversion on AN1
                  STAA  ATDCTL5
                  BRCLR ATDSTAT0,$80,* ; Repeat until A/D signals done
                  LDAA  ATDDR0L        ; A/D conversion is complete in ATDDR0L
                  STAA  0,X            ; so copy it to the sensor register
                  CPX   #SENSOR_STBD   ; If this is the last reading
                  BEQ   RS_EXIT        ; Then exit
                  INC   SENSOR_NUM     ; Else, increment the sensor number
                  INX                  ; and the pointer into the sensor array
                  BRA   RS_MAIN_LOOP   ; and do it again

RS_EXIT           RTS


; -------------------------------------------------------------------------------------------------      
;                               Select Sensor
; -------------------------------------------------------------------------------------------------      
SELECT_SENSOR     PSHA                ; Save the sensor number for the moment
                  LDAA PORTA          ; Clear the sensor selection bits to zeros
                  ANDA #%11100011
                  STAA TEMP           ; and save it into TEMP
                  PULA                ; Get the sensor number
                  ASLA                ; Shift the selection number left, twice
                  ASLA 
                  ANDA #%00011100     ; Clear irrelevant bit positions
                  ORAA TEMP           ; OR it into the sensor bit positions
                  STAA PORTA          ; Update the hardware
                  RTS


; -------------------------------------------------------------------------------------------------      
;                               Display Sensors
; -------------------------------------------------------------------------------------------------
DP_FRONT_SENSOR   EQU TOP_LINE+3
DP_PORT_SENSOR    EQU BOT_LINE+0
DP_MID_SENSOR     EQU BOT_LINE+3
DP_STBD_SENSOR    EQU BOT_LINE+6
DP_LINE_SENSOR    EQU BOT_LINE+9

DISPLAY_SENSORS   LDAA  SENSOR_BOW        ; Get the FRONT sensor value
                  JSR   BIN2ASC           ; Convert to ascii string in D
                  LDX   #DP_FRONT_SENSOR  ; Point to the LCD buffer position
                  STD   0,X               ; and write the 2 ascii digits there
                  LDAA  SENSOR_PORT       ; Repeat for the PORT value
                  JSR   BIN2ASC
                  LDX   #DP_PORT_SENSOR
                  STD   0,X
                  LDAA  SENSOR_MID        ; Repeat for the MID value
                  JSR   BIN2ASC
                  LDX   #DP_MID_SENSOR
                  STD   0,X
                  LDAA  SENSOR_STBD       ; Repeat for the STARBOARD value
                  JSR   BIN2ASC
                  LDX   #DP_STBD_SENSOR
                  STD   0,X
                  LDAA  SENSOR_LINE       ; Repeat for the LINE value
                  JSR   BIN2ASC
                  LDX   #DP_LINE_SENSOR
                  STD   0,X
                  LDAA  #CLEAR_HOME       ; Clear the display and home the cursor
                  JSR   cmd2LCD           ; "
                  LDY   #40               ; Wait 2 ms until "clear display" command is complete
                  JSR   del_50us
                  LDX   #TOP_LINE         ; Now copy the buffer top line to the LCD
                  JSR   putsLCD
                  LDAA  #LCD_SEC_LINE     ; Position the LCD cursor on the second line
                  JSR   LCD_POS_CRSR
                  LDX   #BOT_LINE         ; Copy the buffer bottom line to the LCD
                  JSR   putsLCD
                  RTS

;***************************************************************************************************
;*                      Update Display (Battery Voltage + Current State)                           *
;***************************************************************************************************
UPDT_DISPL        MOVB    #$90,ATDCTL5    ; R-just., uns., sing. conv., mult., ch=0, start
                  BRCLR   ATDSTAT0,$80,*  ; Wait until the conver. seq. is complete
                  LDAA    ATDDR0L         ; Load the ch0 result - battery volt - into A
                  LDAB    #39             ;AccB = 39
                  MUL                     ;AccD = 1st result x 39
                  ADDD    #600            ;AccD = 1st result x 39 + 600
                  JSR     int2BCD
                  JSR     BCD2ASC
                  LDAA    #$8D            ;move LCD cursor to the 1st row, end of msg1
                  JSR     cmd2LCD
                  LDAA    TEN_THOUS       ;output the TEN_THOUS ASCII character
                  JSR     putcLCD 
                  LDAA    THOUSANDS       ;output the THOUSANDS character
                  JSR     putcLCD
                  LDAA    #'.'            ; add the decimal place
                  JSR     putcLCD         ; put the dot into LCD
                  LDAA    HUNDREDS        ;output the HUNDREDS ASCII character
                  JSR     putcLCD         ;same for THOUSANDS, �.� and HUNDREDS
                  LDAA    #$C7            ; Move LCD cursor to the 2nd row, end of msg2
                  JSR     cmd2LCD         ;
                  LDAB    CRNT_STATE      ; Display current state
                  LSLB                    ; "
                  LSLB                    ; "
                  LSLB
                  LDX     #tab            ; "
                  ABX                     ; "
                  JSR     putsLCD         ; "
                  RTS

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


; utility subroutines
;***************************************************************************************************
initLCD:          BSET    DDRB,%11111111  ; configure pins PS7,PS6,PS5,PS4 for output
                  BSET    DDRJ,%11000000  ; configure pins PE7,PE4 for output
                  LDY     #2000
                  JSR     del_50us
                  LDAA    #$28
                  JSR     cmd2LCD
                  LDAA    #$0C
                  JSR     cmd2LCD
                  LDAA    #$06
                  JSR     cmd2LCD
                  RTS

;***************************************************************************************************
clrLCD:           LDAA  #$01
                  JSR   cmd2LCD
                  LDY   #40
                  JSR   del_50us
                  RTS

;***************************************************************************************************
del_50us          PSHX                   ; (2 E-clk) Protect the X register
eloop             LDX   #300             ; (2 E-clk) Initialize the inner loop counter
iloop             NOP                    ; (1 E-clk) No operation
                  DBNE X,iloop           ; (3 E-clk) If the inner cntr not 0, loop again
                  DBNE Y,eloop           ; (3 E-clk) If the outer cntr not 0, loop again
                  PULX                   ; (3 E-clk) Restore the X register
                  RTS                    ; (5 E-clk) Else return

;***************************************************************************************************
cmd2LCD:          BCLR  LCD_CNTR, LCD_RS ; select the LCD instruction
                  JSR   dataMov          ; send data to IR
                  RTS

;***************************************************************************************************
putsLCD:          LDAA  1,X+             ; get one character from  string
                  BEQ   donePS           ; get NULL character
                  JSR   putcLCD
                  BRA   putsLCD

donePS            RTS

;***************************************************************************************************
putcLCD:          BSET  LCD_CNTR, LCD_RS  ; select the LCD data register (DR)c
                  JSR   dataMov           ; send data to DR
                  RTS

;***************************************************************************************************
dataMov:          BSET  LCD_CNTR, LCD_E   ; pull LCD E-signal high
                  STAA  LCD_DAT           ; send the upper 4 bits of data to LCD
                  BCLR  LCD_CNTR, LCD_E   ; pull the LCD E-signal low to complete write oper.
                  LSLA                    ; match the lower 4 bits with LCD data pins
                  LSLA                    ; ""
                  LSLA                    ; ""
                  LSLA                    ; ""
                  BSET  LCD_CNTR, LCD_E   ; pull LCD E-signal high
                  STAA  LCD_DAT           ; send the lower 4 bits of data to LCD
                  BCLR  LCD_CNTR, LCD_E   ; pull the LCD E-signal low to complete write oper.
                  LDY   #1                ; adding this delay allows
                  JSR   del_50us          ; completion of most instructions
                  RTS

;***************************************************************************************************
initAD            MOVB  #$C0,ATDCTL2      ;power up AD, select fast flag clear
                  JSR   del_50us          ;wait for 50 us
                  MOVB  #$00,ATDCTL3      ;8 conversions in a sequence
                  MOVB  #$85,ATDCTL4      ;res=8, conv-clks=2, prescal=12
                  BSET  ATDDIEN,$0C       ;configure pins AN03,AN02 as digital inputs
                  RTS

;***************************************************************************************************
int2BCD           XGDX                    ;Save the binary number into .X
                  LDAA #0                 ;Clear the BCD_BUFFER
                  STAA TEN_THOUS
                  STAA THOUSANDS
                  STAA HUNDREDS
                  STAA TENS
                  STAA UNITS
                  STAA BCD_SPARE
                  STAA BCD_SPARE+1
                  CPX #0                  ; Check for a zero input
                  BEQ CON_EXIT            ; and if so, exit
                  XGDX                    ; Not zero, get the binary number back to .D as dividend
                  LDX #10                 ; Setup 10 (Decimal!) as the divisor
                  IDIV                    ; Divide Quotient is now in .X, remainder in .D
                  STAB UNITS              ; Store remainder
                  CPX #0                  ; If quotient is zero,
                  BEQ CON_EXIT            ; then exit
                  XGDX                    ; else swap first quotient back into .D
                  LDX #10                 ; and setup for another divide by 10
                  IDIV
                  STAB TENS
                  CPX #0
                  BEQ CON_EXIT
                  XGDX                    ; Swap quotient back into .D
                  LDX #10                 ; and setup for another divide by 10
                  IDIV
                  STAB HUNDREDS
                  CPX #0
                  BEQ CON_EXIT
                  XGDX                    ; Swap quotient back into .D
                  LDX #10                 ; and setup for another divide by 10
                  IDIV
                  STAB THOUSANDS
                  CPX #0
                  BEQ CON_EXIT
                  XGDX                    ; Swap quotient back into .D
                  LDX #10                 ; and setup for another divide by 10
                  IDIV
                  STAB TEN_THOUS

CON_EXIT          RTS                     ; Were done the conversion

LCD_POS_CRSR      ORAA #%10000000         ; Set the high bit of the control word
                  JSR cmd2LCD             ; and set the cursor address
                  RTS

;***************************************************************************************************
HEX_TABLE       FCC   '0123456789ABCDEF'    ; Table for converting values


BIN2ASC               PSHA               ; Save a copy of the input number
                      TAB            
                      ANDB #%00001111     ; Strip off the upper nibble
                      CLRA                ; D now contains 000n where n is the LSnibble
                      ADDD #HEX_TABLE     ; Set up for indexed load
                      XGDX                
                      LDAA 0,X            ; Get the LSnibble character
                      PULB                ; Retrieve the input number into ACCB
                      PSHA                ; and push the LSnibble character in its place
                      RORB                ; Move the upper nibble of the input number
                      RORB                ;  into the lower nibble position.
                      RORB
                      RORB 
                      ANDB #%00001111     ; Strip off the upper nibble
                      CLRA                ; D now contains 000n where n is the MSnibble 
                      ADDD #HEX_TABLE     ; Set up for indexed load
                      XGDX                                                               
                      LDAA 0,X            ; Get the MSnibble character into ACCA
                      PULB                ; Retrieve the LSnibble character into ACCB
                      RTS

;***************************************************************************************************
;* BCD to ASCII Conversion Routine
;* This routine converts the BCD number in the BCD_BUFFER
;* into ascii format, with leading zero suppression.
;* Leading zeros are converted into space characters.
;* The flag ?NO_BLANK? starts cleared and is set once a non-zero
;* digit has been detected.
;* The ?units? digit is never blanked, even if it and all the
;* preceding digits are zero.
BCD2ASC           LDAA    #0            ; Initialize the blanking flag
                  STAA    NO_BLANK

C_TTHOU           LDAA    TEN_THOUS     ; Check... (6 KB left)
                  ORAA    NO_BLANK
                  BNE     NOT_BLANK1

ISBLANK1          LDAA    #' '          ; It�s blank
                  STAA    TEN_THOUS     ; so store a space
                  BRA     C_THOU        ; and check the �thousands� digit

NOT_BLANK1        LDAA    TEN_THOUS     ; Get the �ten_thousands� digit
                  ORAA    #$30          ; Convert to ascii
                  STAA    TEN_THOUS
                  LDAA    #$1           ; Signal that we have seen a �non-blank� digit
                  STAA    NO_BLANK

C_THOU            LDAA    THOUSANDS     ; Check the thousands digit for blankness
                  ORAA    NO_BLANK      ; If it�s blank and �no-blank� is still zero
                  BNE     NOT_BLANK2

ISBLANK2          LDAA    #' '          ; Thousands digit is blank
                  STAA    THOUSANDS     ; so store a space
                  BRA     C_HUNS        ; and check the hundreds digit

NOT_BLANK2        LDAA    THOUSANDS     ; (similar to �ten_thousands� case)
                  ORAA    #$30
                  STAA    THOUSANDS
                  LDAA    #$1
                  STAA    NO_BLANK

C_HUNS            LDAA    HUNDREDS      ; Check the hundreds digit for blankness
                  ORAA    NO_BLANK      ; If it�s blank and �no-blank� is still zero
                  BNE     NOT_BLANK3

ISBLANK3          LDAA    #' '          ; Hundreds digit is blank
                  STAA    HUNDREDS       ; so store a space
                  BRA     C_TENS          ; and check the tens digit

NOT_BLANK3        LDAA    HUNDREDS          ; (similar to �ten_thousands� case)
                  ORAA    #$30
                  STAA    HUNDREDS
                  LDAA    #$1
                  STAA    NO_BLANK

C_TENS            LDAA    TENS          ; Check the tens digit for blankness
                  ORAA    NO_BLANK      ; If it�s blank and �no-blank� is still zero
                  BNE     NOT_BLANK4

ISBLANK4          LDAA    #' '          ; Tens digit is blank
                  STAA    TENS          ; so store a space
                  BRA     C_UNITS       ; and check the units digit

NOT_BLANK4        LDAA    TENS          ; (similar to �ten_thousands� case)
                  ORAA    #$30
                  STAA    TENS

C_UNITS           LDAA    UNITS         ; No blank check necessary, convert to ascii.
                  ORAA    #$30
                  STAA    UNITS
                  RTS                 ; We�re done

;***************************************************************************************************

; Display the battery voltage
;----------------------------
                  LDAA    #$C7            ; Move LCD cursor to the 2nd row, end of msg2
                  JSR     cmd2LCD         ;
                  LDAB    CRNT_STATE      ; Display current state
                  LSLB                    ; "
                  LSLB                    ; "
                  LSLB
                  LDX     #tab            ; "
                  ABX                     ; "
                  JSR     putsLCD         ; "
                  RTS

;***************************************************************************************************
;*                                Interrupt Vectors                                                *
;***************************************************************************************************
                  ORG     $FFFE
                  DC.W    Entry ; Reset Vector
                  ORG     $FFDE
                  DC.W    TOF_ISR ; Timer Overflow Interrupt Vector