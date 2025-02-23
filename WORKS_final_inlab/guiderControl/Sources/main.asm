;*****************************************************************
;* This stationery serves as the framework for a                 *
;* user application (single file, absolute assembly application) *
;* For a more comprehensive program that                         *
;* demonstrates the more advanced functionality of this          *
;* processor, please see the demonstration applications          *
;* located in the examples subdirectory of the                   *
;* Freescale CodeWarrior for the HC12 Program directory          *
;*****************************************************************
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
CLEAR_HOME    EQU $01 ; Clear the display and home the cursor
INTERFACE     EQU $38 ; 8 bit interface, two line display
CURSOR_OFF    EQU $0C ; Display on, cursor off
SHIFT_OFF     EQU $06 ; Address increments, no character shift
LCD_SEC_LINE  EQU 64 ; Starting addr. of 2nd line of LCD (note decimal value!)
; LCD Addresses
LCD_CNTR      EQU PTJ ; LCD Control Register: E = PJ7, RS = PJ6
LCD_DAT       EQU PORTB ; LCD Data Register: D7 = PB7, ... , D0 = PB0
LCD_E         EQU $80 ; LCD E-signal pin
LCD_RS        EQU $40 ; LCD RS-signal pin
; Other codes
NULL          EQU 00 ; The string �null terminator�
CR            EQU $0D ; �Carriage Return� character
SPACE         EQU ' ' ; The �space� character
; variable/data section
              ORG $3800
;---------------------------------------------------------------------------
; Storage Registers (9S12C32 RAM space: $3800 ... $3FFF)
SENSOR_LINE   FCB $01 ; Storage for guider sensor readings
SENSOR_BOW    FCB $23 ; Initialized to test values
SENSOR_PORT   FCB $45
SENSOR_MID    FCB $67
SENSOR_STBD   FCB $89
SENSOR_NUM    RMB 1 ; The currently selected sensor
TOP_LINE      RMB 20 ; Top line of display
              FCB NULL ; terminated by null
BOT_LINE      RMB 20 ; Bottom line of display
              FCB NULL ; terminated by null
CLEAR_LINE    FCC ' '
              FCB NULL ; terminated by null
TEMP          RMB 1 ; Temporary location

;Initial based Values for sensors
INIT_LINE     FCB $9D
INIT_BOW      FCB $CA
INIT_MID      FCB $CA
INIT_PORT     FCB $CC
INIT_STAR     FCB $CC

;Initial variance values for sensors
LINE_VAR      FCB  $18
BOW_VAR       FCB  $30
MID_VAR       FCB  $20
PORT_VAR      FCB  $20
STAR_VAR      FCB  $15


; code section
              ORG $4000 ; Start of program text (FLASH memory)
;---------------------------------------------------------------------------
; Initialization
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

MAIN          JSR G_LEDS_ON ; Enable the guider LEDs
              JSR READ_SENSORS ; Read the 5 guider sensors
              JSR G_LEDS_OFF ; Disable the guider LEDs
              JSR UPDT_DISPL
              LDAA CRNT_STATE
              JSR DISPATCHER
              BRA MAIN
              
; Data Section
;********************************************************************



; subroutine section
;*******************************************************************
DISPATCHER    CMPA  #START_ST                    ; If it�s the START state -----------------
              BNE   NOT_START                 ;                                           |
              JSR   START_ST                  ; then call START_ST routine                D
              BRA   DISP_EXIT                 ; and exit                                  I
                                              ; **Refer to page 8**                       S
NOT_START     CMPA  #FWD_ST                      ; **Else if it's the FORWARD state       P
              BNE   NOT_FWD                   ;                                           A
              JSR   FWD_ST                    ; **then call the FORWARD routine
              JMP   DISP_EXIT                 ; **and exit
              
NOT_FWD       CMPA  #REV_ST                      ; **Else if it's the REVERSE state
              BNE   NOT_REV
              JSR   REV_ST                    ; **then call the REVERSE routine
              JMP   DISP_EXIT                 ; and exit
              
NOT_REV       CMPA  #ALL_STP_ST                  ; **Else if it's the ALL_STOP state
              BNE   NOT_ALL_STP
              JSR   ALL_STP_ST                ; **then call the ALL_STOP routine
              JMP   DISP_EXIT                 ; and exit
              
NOT_ALL_STP   CMPA  #FWD_TRN_ST                  ; **Else if it's the FORWARD_TURN state
              BNE   NOT_FWD_TRN
              JSR   FWD_TRN_ST                ; then call the FORWARD_TURN routine
              JMP   DISP_EXIT                 ; and exit
             
                                              ;                                           T
NOT_FWD_TRN   CMPA  #REV_TRN_ST                  ; Else if it�s the REV_TRN state         C
              BNE   NOT_REV_TRN               ;                                           H
              JSR   REV_TRN_ST                ; then call REV_TRN_ST routine              E
              BRA   DISP_EXIT                 ; and exit                                  R
                                              ;                                           |
NOT_REV_TRN   SWI                             ; Else the CRNT_ST is not defined, so stop  |
DISP_EXIT     RTS                             ; Exit from the state dispatcher ----------

;*******************************************************************   START STATE
START_ST      BRCLR PORTAD0,$04,NO_FWD        ; **If /FWD_BUMP Refer to page 9
              JSR   INIT_FWD                  ; **Initialize the FORWARD state
              MOVB  #FWD,CRNT_STATE           ; **Go into the FORWARD state
              BRA   START_EXIT
            
NO_FWD        NOP                             ; Else
START_EXIT    RTS                             ; return to the MAIN routine

;******************************************************************* FORWARD STATE
FWD_ST        BRSET PORTAD0,$04,NO_FWD_BUMP   ; **If FWD_BUMP then **Refer to page 11
              JSR   INIT_REV                  ; **initialize the REVERSE routine
              MOVB  #REV,CRNT_STATE           ; **set the state to REVERSE
              JMP   FWD_EXIT                  ; **and return
              
NO_FWD_BUMP   BRSET PORTAD0,$08,NO_REAR_BUMP  ; **If REAR_BUMP, then we should stop
              JSR   INIT_ALL_STP              ; **so initialize the ALL_STOP state
              MOVB  #ALL_STP,CRNT_STATE       ; **and change state to ALL_STOP
              JMP   FWD_EXIT                  ; **and return
              
NO_REAR_BUMP  LDAA  TOF_COUNTER               ; **If Tc>Tfwd then
              CMPA  T_FWD                     ; **the robot should make a turn
              BNE   NO_FWD_TRN                ; **so
              JSR   INIT_FWD_TRN              ; **initialize the FORWARD_TURN state
              MOVB  #FWD_TRN,CRNT_STATE       ; **and go to that state
              JMP   FWD_EXIT
            
NO_FWD_TRN    NOP                             ; Else
FWD_EXIT      RTS                             ; return to the MAIN routine

;*******************************************************************  REVERSE STATE
REV_ST        LDAA  TOF_COUNTER               ; If Tc>Trev then
              CMPA  T_REV                     ; the robot should make a FWD turn
              BNE   NO_REV_TRN                ; so
              JSR   INIT_REV_TRN              ; initialize the REV_TRN state
              MOVB  #REV_TRN,CRNT_STATE       ; set state to REV_TRN
              BRA   REV_EXIT                  ; and return
            
NO_REV_TRN    NOP                             ; Else
REV_EXIT      RTS                             ; return to the MAIN routine

;******************************************************************* ALL STOP STATE
ALL_STP_ST    BRSET PORTAD0,$04,NO_START      ; If FWD_BUMP
              BCLR  PTT,%00110000             ; initialize the START state (both motors off)
              MOVB  #START,CRNT_STATE         ; set the state to START
              BRA   ALL_STP_EXIT              ; and return
              
NO_START      NOP                             ; Else
ALL_STP_EXIT  RTS                             ; return to the MAIN routine

;*******************************************************************  FORWARD TURN STATE
FWD_TRN_ST    LDAA  TOF_COUNTER               ; If Tc>Tfwdturn then
              CMPA  T_FWD_TRN                 ; the robot should go FWD
              BNE   NO_FWD_FT                 ; so
              JSR   INIT_FWD                  ; initialize the FWD state
              MOVB  #FWD,CRNT_STATE           ; set state to FWD
              BRA   FWD_TRN_EXIT              ; and return
              
NO_FWD_FT     NOP                             ; Else
FWD_TRN_EXIT  RTS                             ; return to the MAIN routine

;******************************************************************* REVERSE TURN STATE
REV_TRN_ST    LDAA  TOF_COUNTER               ; If Tc>Trevturn then
              CMPA  T_REV_TRN                 ; the robot should go FWD
              BNE   NO_FWD_RT                 ; so
              JSR   INIT_FWD                  ; initialize the FWD state
              MOVB  #FWD,CRNT_STATE           ; set state to FWD
              BRA   REV_TRN_EXIT              ; and return
              
NO_FWD_RT     NOP                             ; Else
REV_TRN_EXIT  RTS                             ; return to the MAIN routine

;*******************************************************************  
INIT_FWD      BCLR  PORTA,%00000011           ; Set FWD direction for both motors
              BSET  PTT,%00110000             ; Turn on the drive motors
              LDAA  TOF_COUNTER               ; Mark the fwd time Tfwd
              ADDA  #FWD_INT
              STAA  T_FWD
              RTS
              
;*******************************************************************
INIT_REV      BSET  PORTA,%00000011           ; Set REV direction for both motors
              BSET  PTT,%00110000             ; Turn on the drive motors
              LDAA  TOF_COUNTER               ; Mark the fwd time Tfwd
              ADDA  #REV_INT
              STAA  T_REV
              RTS
              
;*******************************************************************
INIT_ALL_STP  BCLR  PTT,%00110000             ; Turn off the drive motors
              RTS
              
;*******************************************************************
INIT_FWD_TRN  BSET  PORTA,%00000010           ; Set REV dir. for STARBOARD (right) motor
              LDAA  TOF_COUNTER               ; Mark the fwd_turn time Tfwdturn
              ADDA  #FWD_TRN_INT
              STAA  T_FWD_TRN
              RTS
              
;*******************************************************************
INIT_REV_TRN  BCLR  PORTA,%00000010           ; Set FWD dir. for STARBOARD (right) motor
              LDAA  TOF_COUNTER               ; Mark the fwd time Tfwd
              ADDA  #REV_TRN_INT
              STAA  T_REV_TRN
              RTS

; Initialize ports

INIT          BCLR DDRAD,$FF ; Make PORTAD an input (DDRAD @ $0272)
              BSET DDRA,$FF ; Make PORTA an output (DDRA @ $0002)
              BSET DDRB,$FF ; Make PORTB an output (DDRB @ $0003)
              BSET DDRJ,$C0 ; Make pins 7,6 of PTJ outputs (DDRJ @ $026A)
              RTS
;---------------------------------------------------------------------------
; Initialize the ADC

openADC       MOVB #$80,ATDCTL2 ; Turn on ADC (ATDCTL2 @ $0082)
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
CLR_LCD_BUF   LDX #CLEAR_LINE
              LDY #TOP_LINE
              JSR STRCPY

CLB_SECOND    LDX #CLEAR_LINE
              LDY #BOT_LINE
              JSR STRCPY

CLB_EXIT      RTS
;---------------------------------------------------------------------------
; String Copy
; Copies a null-terminated string (including the null) from one location to
; another
; Passed: X contains starting address of null-terminated string
; Y contains first address of destination
STRCPY        PSHX ; Protect the registers used
              PSHY
              PSHA
STRCPY_LOOP   LDAA 0,X ; Get a source character
              STAA 0,Y ; Copy it to the destination
              BEQ STRCPY_EXIT ; If it was the null, then exit
              INX ; Else increment the pointers
              INY
              BRA STRCPY_LOOP ; and do it again
STRCPY_EXIT   PULA ; Restore the registers
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
G_LEDS_ON     BSET PORTA,%00100000 ; Set bit 5
              RTS
;
; Guider LEDs OFF
; This routine disables the guider LEDs. Readings of the sensor
; correspond to the �ambient lighting� situation.
; Passed: Nothing
; Returns: Nothing
; Side: PORTA bit 5 is changed
G_LEDS_OFF    BCLR PORTA,%00100000 ; Clear bit 5
              RTS
;---------------------------------------------------------------------------
; Read Sensors

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

DP_FRONT_SENSOR EQU TOP_LINE+3
DP_PORT_SENSOR  EQU BOT_LINE+0
DP_MID_SENSOR   EQU BOT_LINE+3
DP_STBD_SENSOR  EQU BOT_LINE+6
DP_LINE_SENSOR  EQU BOT_LINE+9

DISPLAY_SENSORS LDAA SENSOR_BOW ; Get the FRONT sensor value
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
;---------------------------------------------------------------------------
; Binary to ASCII
; Converts an 8 bit binary value in ACCA to the equivalent ASCII character 2
; character string in accumulator D
; Uses a table-driven method rather than various tricks.
; Passed: Binary value in ACCA
; Returns: ASCII Character string in D
; Side Fx: ACCB is destroyed
HEX_TABLE       FCC '0123456789ABCDEF' ; Table for converting values

BIN2ASC         PSHA ; Save a copy of the input number on the stack
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
                RTS
;---------------------------------------------------------------------------
; Routines to control the Liquid Crystal Display
;---------------------------------------------------------------------------
; Initialize the LCD

openLCD         LDY #2000 ; Wait 100 ms for LCD to be ready
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
                
;---------------------------------------------------------------------------
; Send a command in accumulator A to the LCD

cmd2LCD         BCLR LCD_CNTR,LCD_RS ; Select the LCD Instruction register
                JSR dataMov ; Send data to IR or DR of the LCD
                RTS
;---------------------------------------------------------------------------
; Send a character in accumulator in A to LCD

putcLCD         BSET LCD_CNTR,LCD_RS ; select the LCD Data register
                JSR dataMov ; send data to IR or DR of the LCD
                RTS
;---------------------------------------------------------------------------
; Send a NULL-terminated string pointed to by X

putsLCD         LDAA 1,X+ ; get one character from the string
                BEQ donePS ; reach NULL character?
                JSR putcLCD
                BRA putsLCD
donePS          RTS

;---------------------------------------------------------------------------
; Send data to the LCD IR or DR depending on the RS signal

dataMov         BSET LCD_CNTR,LCD_E ; pull the LCD E-sigal high
                STAA LCD_DAT ; send the 8 bits of data to LCD
                NOP
                NOP
                NOP
                BCLR LCD_CNTR,LCD_E ; pull the E signal low to complete the write operation
                
                LDY #1 ; adding this delay will complete the internal
                JSR del_50us ; operation for most instructions
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
              
;---------------------------------------------------------------------------
; 50 Microsecond Delay

del_50us      PSHX ; (2 E-clk) Protect the X register
eloop         LDX #300 ; (2 E-clk) Initialize the inner loop counter
iloop         NOP ; (1 E-clk) No operation
              DBNE X,iloop ; (3 E-clk) If the inner cntr not 0, loop again
              DBNE Y,eloop ; (3 E-clk) If the outer cntr not 0, loop again
              PULX ; (3 E-clk) Restore the X register
              RTS ; (5 E-clk) Else return


;**************************************************************
;*                 Interrupt Vectors                          *
;**************************************************************
            ORG   $FFFE
            DC.W  Entry           ; Reset Vector