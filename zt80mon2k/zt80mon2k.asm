; 
; ZT80MON
; ACIA 6551A SERIAL IO (BASIC)
; 

; MEMMAP

STACKSYS:    EQU     $FF00 
;ROMBASE:    EQU     $0000
MONROMDATA:  EQU     $0700 
;RAMBASE:    EQU     $8000
MONRAMDATA:  EQU     $FF01 

CLI_LINE_MAX: EQU    $0F 

; IO
; ACIA6551 ADDRESS
ACIA_DATA:   EQU     0x08 
ACIA_STAT:   EQU     0x09 
ACIA_CMD:    EQU     0x0A 
ACIA_CTL:    EQU     0x0B 

;--------------------------------------------

            ORG    $0000 

MAIN:                

; SET STACK POINTER
            LD      SP,STACKSYS 

; TEST IO PORTS (LEDS)
            CALL    INIT_IOTEST 

; 6551A INIT
            CALL    INIT_HARDWARE 

; HELLO SERIAL OUTPUT
;CALL    OUT_HELLO

; IDENTIFY MONITOR
;LD      HL, STR_ZTMON
;CALL    PRINT_STRING
;LD      HL, STR_ZTMVER
;CALL    PRINT_STRING


LOOP:                
            CALL    MONITOR 

INC_IDLE:            
; NO RECEIVED CHAR
            JP      LOOP 

;--------------------------------------------
OUTCHAR:             
            CALL    A6551_OUTCHAR 
            RET      

;--------------------------------------------
INCHAR:              
            CALL    A6551_INCHAR 
            RET      

;--------------------------------------------
SERIAL_WRITE_A:      
            CALL    A6551_OUTCHAR 
            RET      

;--------------------------------------------
SERIAL_READ_A:       
            PUSH    BC 

;--------------------------------------------
SERIAL_READ_A_LOOP:  
            CALL    A6551_INCHAR 

; CHAR RECEIVED ?
            LD      C,B 
            LD      B,%00001000 
            AND     B 
            JP      NZ,SERIAL_READ_A_LOOP 
; YES, CHAR RECEIVED
            LD      A,C 
            POP     BC 
            RET      

;--------------------------------------------
; INIT_HARDWARE
; NO ARGUMENTS
; NO RETURN
; 
INIT_HARDWARE:       
            CALL    A6551_INIT 
            RET      

;--------------------------------------------
; 
; 6551 DRIVER
; 
;--------------------------------------------

;--------------------------------------------
; 6551_INIT
; NO ARGUMENTS
; NO RETURN
; 
A6551_INIT:          
; ACIA 6551 INIT
            LD      A,%00000000 ;SOFTWARE RESET
            OUT     (ACIA_CMD),A 
            LD      A,%00001011 ;NO PARITY, NO ECHO, NO INTERRUPT
            OUT     (ACIA_CMD),A 
            LD      A,%00011111 ;1 STOP BIT, 8 DATA BITS, 19200 BAUD
            OUT     (ACIA_CTL),A 
            RET      

;--------------------------------------------
; OUTCHAR
; ARGUMENTS
; A = CHAR TO OUTPUT
; 
A6551_OUTCHAR:       
            LD      C,A 
            PUSH    BC 
A6551_OUTCHART:      
; CHECK TRANSMIT FLAG IS SET
            LD      B,%00010000 ; 
            IN      A,(ACIA_STAT) 
;OUT     ($00),A         ;SHOW STAT ON LEDS
            AND     B 
            JP      Z,A6551_OUTCHART 
; SEND CHAR
            LD      A,C 
            OUT     (ACIA_DATA),A 
            POP     BC 
            RET      
;--------------------------------------------
; INCHAR
; NO ARGUMENTS
; RETURN
; A = 0 OR %00001000 (CHAR RECEIVED / CHAR RECEIVED)
; B = RECEIVED CHAR CODE
; 
A6551_INCHAR:        
            PUSH    DE 
            LD      D,$00 
; CHECK RECEIV FLAG IS SET
            LD      B,%00001000 
            IN      A,(ACIA_STAT) 
;OUT     ($00),A         ;SHOW STAT ON LEDS
            AND     B 
            JP      Z,A6551_INCHAR_ 
; READ RECEIVE REGISTER
            IN      A,(ACIA_DATA) 
            LD      D,A 
            LD      B,$00 
A6551_INCHAR_:       
; NO RECEIVED CHAR
            LD      A,B 
            LD      B,D 
            POP     DE 
            RET      

;--------------------------------------------
; SHOW 6551 REGISTERS ON LEDS
; NO ARGUMENTS
; NO RETURN
; 
A6551_STATUS:        
; LED SHOW FF
            LD      A,$FF 
            OUT     ($00),A 
; SHOW CMD REG
            IN      A,(ACIA_CMD) 
            OUT     ($00),A 
; SHOW CTL REG
            IN      A,(ACIA_CTL) 
            OUT     ($00),A 
; SHOW STAT REG
            IN      A,(ACIA_STAT) 
            OUT     ($00),A 
            RET      

;--------------------------------------------
; 
; DEBUG CODE
; 
;--------------------------------------------

; 
; LED HELLO WORLD
; NO ARGUMENTS
; NO RETURN
; 
INIT_IOTEST:         
; TEST IO PORTS
            LD      A,0x01 
            OUT     (0x00),A 
            IN      A,(0x00) 
            OUT     (0x00),A 
            LD      A,0xFF 
            OUT     (0x00),A 
            LD      A,0x00 
            OUT     (0x00),A 
            NOP      
            RET      

;--------------------------------------------
; 
; RESET
; 
;--------------------------------------------

RESET:               
            RST     0x00 

;--------------------------------------------
; 
; STRINGS
; 
;--------------------------------------------

CONVERTTOUPPER:      
            PUSH    HL 
CONVERTTOUPPER00:    
            LD      A,(HL) 
            CP      $0 
            JR      Z,CONVERTTOUPPER03 
            CP      "A" 
            JR      Z,CONVERTTOUPPER01 
            JR      C,CONVERTTOUPPER02 
            CP      "Z" 
            JR      Z,CONVERTTOUPPER01 
            JR      NC,CONVERTTOUPPER02 
CONVERTTOUPPER01:    
            SUB     32 
            LD      (HL),A 
CONVERTTOUPPER02:    
            INC     HL 
            JR      CONVERTTOUPPER00 
CONVERTTOUPPER03:    
            POP     HL 
            RET      

;--------------------------------------------

; PRINT_STRING
; ARGUMENTS
; A = SSTRING START ADDRESS
; 
PRINTSTRINGA:        
            LD      A,(HL) 
            CP      $00 
            RET     Z 
            CALL    OUTCHAR 
            INC     HL 
            JR      PRINTSTRINGA 

;--------------------------------------------

PRINT3STRINGS:       
            CALL    PRINTSTRINGA 
            EX      DE,HL 
            CALL    PRINTSTRINGA 
            LD      H,B 
            LD      L,C 
            JR      PRINTSTRINGA 


;--------------------------------------------

READLINEA:           
            PUSH    HL 
            LD      B,0 
READLINEA00:         
            CALL    SERIAL_READ_A 
; CHECK FOR BACKSPACE
            CP      0x7F ; BACKSPACE
            JR      Z,READLINEABACKSPACE 
; CHECK FOR END OF LINE
            CP      "\R" 
            JR      Z,READLINEA01 
; CHECK FOR ABORT WITH CTRL-C
            CP      0x03 ; CTRL-C
            JR      Z,READLINEA02 
; IF NOT ANY OF THE ABOVE CASES, WE'RE
; DEALING WITH A "REAL CHAR".
; DO WE HAVE BUFFER SPACE TO HANDLE IT?
            LD      C,A ; BACKUP CHAR
            LD      A,B 
            CP      80 
            JR      Z,READLINEABACKSPACEEND 
            LD      A,C ; RESTORE CHAR
; WE HAVE BUFFER SPACE, SO ECHO THE CHAR,
; STORE IT IN MEM AND INCREMENT THE BUFFER
; POINTER AND CHAR COUNT
            CALL    SERIAL_WRITE_A 
            LD      (HL),A 
            INC     HL 
            INC     B 
            JR      READLINEA00 
READLINEABACKSPACE:  
; HANDLE BACKSPACE
; ARE WE ALREADY AT CURSOR?
            LD      A,0 
            CP      B 
            JR      Z,READLINEABACKSPACEEND 
            DEC     HL 
            DEC     B 
            PUSH    HL 
            LD      HL,BACKSPACECONTROLSEQ 
            CALL    PRINTSTRINGA 
            POP     HL 
; READ NEXT CHAR
            JR      READLINEA00 
READLINEABACKSPACEEND:  
            LD      A,0x1B 
            CALL    SERIAL_WRITE_A 
            LD      A,"G" 
            CALL    SERIAL_WRITE_A 
            JR      READLINEA00 
BACKSPACECONTROLSEQ:  
            ;DS      0x1B,0x5B,"D",0x1B,0x5B,"P",0x00
            DB      0x1B,0x5B,"D",0x1B,0x5B,"P",0x00
READLINEA01:         
; HANDLE ENTER
            CALL    SERIAL_WRITE_A ; ECHO THE \R
            LD      A,"\N" 
            CALL    SERIAL_WRITE_A 
; TERMINATE STRING
            LD      (HL),$00 
            POP     HL 
            CP      A ; SET ZERO FLAG
            RET      
READLINEA02:         
; HANDLE CTRL-C
            LD      HL,MESSAGE_BUFFER 
            CALL    TERMINATELINE 
            LD      HL,MESSAGE_BUFFER 
            CALL    PRINTSTRINGA 
            POP     HL 
            OR      1 ; RESET ZERO FLAG
            RET      


;--------------------------------------------
STRCMP:              
            LD      A,(HL) 
            CP      $0 
            RET     Z 
            LD      B,A 
            LD      A,(DE) 
            CP      $0 
            RET     Z 
            CP      B 
            RET     NZ 
            INC     HL 
            INC     DE 
            JR      STRCMP 

STRICTSTRCMP:        
; LOAD NEXT CHARS OF EACH STRING
            LD      A,(DE) 
            LD      B,A 
            LD      A,(HL) 
; COMPARE
            CP      B 
; RETURN NON-ZERO IF CHARS DON'T MATCH
            RET     NZ 
; CHECK FOR END OF BOTH STRINGS
            CP      0 ;"\0"
; RETURN IF STRINGS HAVE ENDED
            RET     Z 
; OTHERWISE, ADVANCE TO NEXT CHARS
            INC     HL 
            INC     DE 
            JR      STRICTSTRCMP 

STRLEN:              
            PUSH    HL 
            LD      B,0 
STRLEN00:            
            LD      A,(HL) 
            CP      0 ;"\0"
            JR      Z,STRLEN01 
            INC     HL 
            INC     B 
            JR      STRLEN00 
STRLEN01:            
            POP     HL 
            LD      A,B 
            RET      

STRADDCHAR:          
; COPY CHAR IN A TO HL AND INC
            LD      (HL),A 
            INC     HL 
            RET      

ISSTRDEC:            
            PUSH    HL 
ISSTRDEC00:          
            LD      A,(HL) 
; TEST FOR END OF STRING
            CP      0 ;"\0"
            JR      Z,ISSTRDECTRUE 
; FAIL IF < "0"
            CP      "0" 
            JR      C,ISSTRDECFALSE 
; CONTINUE IF <= "9" (< "9"+1)
            CP      "9"+1 
            JR      C,ISSTRDECCONTINUE 
            CP      "9" 
; FALL THROUGH TO FAIL OTHERWISE
ISSTRDECFALSE:       
            OR      1 ; RESET ZERO FLAG
            POP     HL 
            RET      
ISSTRDECTRUE:        
            CP      A ; SET ZERO FLAG
            POP     HL 
            RET      
ISSTRDECCONTINUE:    
            INC     HL 
            JR      ISSTRDEC00 

ISSTRHEX:            
            PUSH    HL 
ISSTRHEX00:          
            LD      A,(HL) 
; TEST FOR END OF STRING
            CP      0 ;"\0"
            JR      Z,ISSTRHEXTRUE 
; FAIL IF < "0"
            CP      "0" 
            JR      C,ISSTRHEXFALSE 
; CONTINUE IF <= "9" (< "9"+1)
            CP      "9"+1 
            JR      C,ISSTRHEXCONTINUE 
; FAIL IF < "A"
            CP      "0" 
            JR      C,ISSTRHEXFALSE 
; CONTINUE IF <= "F" (< "F"+1)
            CP      "F"+1 
            JR      C,ISSTRHEXCONTINUE 
; FALL THROUGH TO FAIL OTHERWISE
ISSTRHEXFALSE:       
            OR      1 ; RESET ZERO FLAG
            POP     HL 
            RET      
ISSTRHEXTRUE:        
            CP      A ; SET ZERO FLAG
            POP     HL 
            RET      
ISSTRHEXCONTINUE:    
            INC     HL 
            JR      ISSTRHEX00 

STRTOK:              
            PUSH    HL ; PUSH START ADDRESS OF STRING
STRTOK00:            
            LD      A,(HL) 
            CP      " " 
            JR      Z,STRTOK01 
            CP      0 ;"\0"
            JR      Z,STRTOK02 
            INC     HL 
            JR      STRTOK00 
STRTOK01:            
            LD      (HL),0 ; "\0" ; TERMINATE STRING
STRTOK02:            
            INC     HL ; ADVANCE HL TO	START OF NEXT STRING
; PUT START ADDRESS OF NEXT STRING IN DE
            EX      DE,HL 
            POP     HL ; POP ORIGINAL STRING START
            RET      

SKIPWHITESPACE:      
            LD      A,(HL) 
            CP      " " 
            RET     NZ 
            INC     HL 
            JR      SKIPWHITESPACE 

STRSTRIP:            
            LD      A,(HL) 
            CP      0 ;"\0"
            JR      Z,STRSTRIP01 
            INC     HL 
            JR      STRSTRIP 
STRSTRIP01:          
            DEC     HL 
            LD      A,(HL) 
            CP      " " 
            JR      NZ,STRSTRIPEND 
            LD      (HL),0 ;"\0"
            JR      STRSTRIP01 
STRSTRIPEND:         
            INC     HL 
            RET      

;--------------------------------------------


READ8BIT:            
; HL IS A POINTER TO A TWO-CHAR STRING
; THIS IS READ AS AN 8 BIT HEX NUMBER
; THE NUMBER IS STORED IN A
            LD      A,(HL) ; COPY FIRST CHAR TO A
            CALL    HEX12 ; CONVERT FIRST CHAR
            ADD     A,A ; MULTIPLY BY 16...
            ADD     A,A ; ...
            ADD     A,A ; ...
            ADD     A,A ; ...DONE!
            LD      D,A ; STORE TOP 4 BITS IN D
            INC     HL ; ADVANCE TO NEXT CHAR
            LD      A,(HL) 
            CALL    HEX12 ; CONVERT SECOND CHAR
            OR      D ; ADD BACK TOP BITS
            INC     HL ; ADVANCE FOR NEXT GUY
            RET      
HEX12:      SUB     "0" 
            CP      10 
            RET     C 
            SUB     "A"-"0"-10 
            RET      

READ16BIT:           
; HL IS A POINTER TO A FOUR-CHAR STRING
; THIS IS READ AS A 16 BIT HEX NUMBER
; THE NUMBER IS STORED IN BC
            CALL    READ8BIT 
            LD      B,A 
            CALL    READ8BIT 
            LD      C,A 
            RET      

;--------------------------------------------

READBCDBYTE:         
; HL IS A POINTER TO A TWO-CHAR STRING
; THIS IS READ AS A DECIMAL NUMBER (ASSUMED <=80)
; THE NUMBER IS STORED IN A IN BCD FORMAT
            LD      A,(HL) 
            INC     HL 
            SUB     "0" 
            SLA     A 
            SLA     A 
            SLA     A 
            SLA     A 
            LD      B,A 
            LD      A,(HL) 
            INC     HL 
            SUB     "0" 
            OR      B 
            RET      

;--------------------------------------------

TERMINATELINE:       
            LD      (HL),"\N" 
            INC     HL 
            LD      (HL),"\R" 
            INC     HL 
            LD      (HL),$00 
            RET      

;--------------------------------------------

STRFHEX:             
; CONVERT BYTE IN A TO TWO-CHAR HEX AND APPEND TO HL
            LD      C,A ; A = NUMBER TO CONVERT
            CALL    NUM1 
            LD      (HL),A 
            INC     HL 
            LD      A,C 
            CALL    NUM2 
            LD      (HL),A 
            INC     HL 
            RET      
NUM1:       RRA      
            RRA      
            RRA      
            RRA      
NUM2:       OR      $F0 
            DAA      
            ADD     A,$A0 
            ADC     A,$40 ; ASCII HEX AT THIS POINT (0 TO F)
            RET      

;--------------------------------------------
; 
; .MONITOR CLI
; 
;--------------------------------------------

MONITOR:             
; BACKUP STACK POINTER
            LD      (MON_STACK_BACKUP),SP 
            LD      SP,MON_STACK+1 
; SAVE ALL REGISTERS
            PUSH    AF 
            PUSH    BC 
            PUSH    DE 
            PUSH    HL 
            EX      AF,AF' 
            EXX      
            PUSH    AF 
            PUSH    BC 
            PUSH    DE 
            PUSH    HL 
            EX      AF,AF' 
            EXX      
            PUSH    IX 
            PUSH    IY 
MONITORSTART:        
            LD      HL,MONWELCOMESTR 
            CALL    PRINTSTRINGA 
            CALL    REGISTERS 
            ;CALL    STACK 
MONITORLOOP:         
; INFINITE LOOP OF READ, PARSE, DISPATCH
            LD      HL,MONPROMPTSTR 
            CALL    PRINTSTRINGA 
            LD      HL,MON_LINEBUF 
            CALL    READLINEA 
            JR      NZ,MONITORLOOP ; USER STOPPED INPUT USING CTRL-C
            LD      HL,MON_LINEBUF 
            LD      A,(HL) 
            CP      $00 
            JR      Z,MONITORLOOP 
            CALL    MONITORHANDLELINE 
            JR      MONITORLOOP 
MONITOREXIT:         
            POP     IY 
            POP     IX 
            EX      AF,AF' 
            EXX      
            POP     HL 
            POP     DE 
            POP     BC 
            POP     AF 
            EX      AF,AF' 
            EXX      
            POP     HL 
            POP     DE 
            POP     BC 
            POP     AF 
; RESTORE ORIGINAL STACK POINTER
            LD      SP,(MON_STACK_BACKUP) 
            RET      
MONWELCOMESTR:       
            DB      "ZT80MON V0.003\R\N",0 
MONPROMPTSTR:        
            DB      "$ ",0 

MONITORHANDLELINE:   
            LD      BC,MON_ARGC 
            LD      DE,MON_DISPATCH_TABLE 
            CALL    HANDLECOMMANDLINE 
            RET      

;--------------------------------------
; 
; COMMAND DISPATCH
; 
;--------------------------------------

; COMMAND STRINGS


;CONTINUESTR: DB     "CONTINUE",0 
DUMPSTR:    DB      "DUMP",0 
INSTR:      DB      "IN",0 
HELPSTR:    DB      "HELP",0 
JUMPSTR:    DB      "JUMP",0 
;MEMCPYSTR:  DB      "MEMCPY",0 
MEMEDSTR:   DB      "MEMED",0 
REGSTR:     DB      "REGISTERS",0 
;STACKSTR:   DB      "STACK",0 
OUTSTR:     DB      "OUT",0 
;PUSHSTR:    DB      "PUSH",0 
;POPSTR:     DB      "POP",0 
NULLSTR:    DB      0 


; DOS.Z80
RESETSTR:   DB      "RESET",0 
EXPECTSEXACTLYONEARGSTR:  
            DB      " EXPECTS EXACTLY ONE ARG ",0 
ADDRESSSTR:          
            DB      "(MEM ADDRESS)\R\N",0 

; TABLE LINKING COMMAND STRINGS TO FUNCTION ENTRY POINTS
MON_DISPATCH_TABLE:  
;            DW      CONTINUESTR,CONTINUE 
            DW      DUMPSTR,DUMP 
            DW      INSTR,IN 
            DW      HELPSTR,HELP 
            DW      JUMPSTR,JUMP 
;            DW      MEMCPYSTR,MEMCPY 
            DW      MEMEDSTR,MEMED 
            DW      OUTSTR,OUT 
;            DW      PUSHSTR,PUSH 
;            DW      POPSTR,POP 
            DW      REGSTR,REGISTERS 
            DW      RESETSTR,RESET 
;            DW      STACKSTR,STACK 
            DW      NULLSTR,WHAT 

;--------------------------------------------

;CONTINUE:            
; POP THE RETURN ADDRESS WHICH LEADS BACK TO THE MONITOR LOOP
;            POP     HL ; BREAK OUT OF DISPATCH
;            POP     HL ; BREAK OUT OF HANDLECOMMANDLINE
;            POP     HL ; BREAK OUT OF MONITORHANDLELINE
; BREAK OUT OF MONITOR LOOP
;            JP      MONITOREXIT 

;--------------------------------------------

DUMP:                
; CHECK ARGUMENT COUNT
            LD      A,(MON_ARGC) 
            CP      1 
            JR      Z,DUMP00 
; ARGC ERROR
            LD      HL,DUMPSTR 
ONEMEMADDRESSARGCERROR:  
            LD      DE,EXPECTSEXACTLYONEARGSTR 
            LD      BC,ADDRESSSTR 
            JP      PRINT3STRINGS 
DUMP00:              
            LD      HL,(MON_ARGV) 
            CALL    VALIDATEADDRESS 
            JR      Z,DUMP01 
            RET      
DUMP01:              
            CALL    READ16BIT ; READ ADDRESS INTO BC
            LD      D,B 
            LD      E,C 
DUMPPREOUTER:        
            LD      B,16 ; WE DUMP 16 ROWS
DUMPOUTER:           
            PUSH    BC ; STORE ROW COUNTER
            LD      HL,MON_LINEBUF 
            LD      B,16 ; WE DUMP 16 COLUMNS
            PUSH    DE ; STORE MEM POINTER AT START OF ROW
DUMPINNER:           
; PRINT ADDRESS
            LD      A,D 
            CALL    STRFHEX 
            LD      A,E 
            CALL    STRFHEX 
            LD      (HL),"\T" 
            INC     HL 
; PRINT OUT HEX VERSION OF DATA
DUMPINNER2:          
            LD      A,(DE) ; READ FROM DE TO A
            INC     DE 
            CALL    STRFHEX 
            LD      (HL)," " 
            INC     HL 
            DJNZ    DUMPINNER2 
; PRINT SEPARATOR BETWEEN HEX AND ASCII
            LD      (HL),"\T" 
            INC     HL 
; NOW REWIND OUR MEMORY POINTER TO DO THE ASCII BIT
            POP     DE 
; PRINT OUT ASCII VERSION OF DATA
            LD      B,16 ; WE DUMP 16 COLUMNS
DUMPINNER3:          
            LD      A,(DE) ; READ FROM DE TO A
            INC     DE 
            CP      32 
            JR      Z,HANDLEPRINTABLE 
            JR      C,HANDLENONPRINTABLE 
            CP      127 
            JR      Z,HANDLEPRINTABLE 
            JR      C,HANDLEPRINTABLE 
HANDLENONPRINTABLE:  
            LD      A,"." ; CLOBBER UNPRINTABLE CHAR WITH DOT
HANDLEPRINTABLE:     
            LD      (HL),A 
; CONTINUE LOOP
            INC     HL 
            DJNZ    DUMPINNER3 
; NOW TERMIATE THIS LINE
            CALL    TERMINATELINE 
            LD      HL,MON_LINEBUF 
            CALL    PRINTSTRINGA 
            POP     BC ; RETRIEVE ROW COUNTER
            DJNZ    DUMPOUTER 
; ASK TO CONTINUE
DUMP04:              
            LD      HL,DUMPCONTINUESTR 
            CALL    PRINTSTRINGA 
            CALL    SERIAL_READ_A 
            PUSH    AF 
            CALL    CLEARLEFT 
            POP     AF 
            CP      " " 
            JR      Z,DUMPPREOUTER ; CONTINUE
            CP      0x03 
            RET     Z ; END
            JR      DUMP04 ; ASK AGAIN
; 
DUMPCONTINUESTR:     
            DB      "(SPACE TO CONTINUE, CTRL-C TO END)",0 
CLEARLEFT:           
            LD      HL,CLEARLEFTCODE 
            CALL    PRINTSTRINGA 
            RET      
CLEARLEFTCODE:       
            DB      0x1B,0x5B 
            DB      "1K\R",0 

;--------------------------------------------

IN:                  
            LD      A,(MON_ARGC) 
            CP      1 
            JR      Z,IN00 
; ARGC ERROR
            LD      HL,INSTR 
            LD      DE,EXPECTSEXACTLYONEARGSTR 
            LD      BC,INARGSSTR 
            JP      PRINT3STRINGS 
INARGSSTR:           
            DB      "(PORT)\R\N",0 
IN00:                
            LD      HL,(MON_ARGV) 
            CALL    READ8BIT 
            LD      C,A 
            IN      A,(C) 
            LD      HL,MON_LINEBUF ; POINT TO START OF OUTPUT
            CALL    STRFHEX ; WRITE HEX STRING
            CALL    TERMINATELINE ; ADD \N\R\0
            LD      HL,MON_LINEBUF ; PRINT OUTPUT
            CALL    PRINTSTRINGA 
            RET      

;--------------------------------------------

HELP:                
            LD      HL,HELPMESSAGE 
            CALL    PRINTSTRINGA 
            RET      
; 
HELPMESSAGE:         
            DB      "MONITOR COMMANDS:\N\R" 
;            DB      "CONTINUE: RESUME PROGRAM EXECUTION\N\R" 
            DB      "DUMP ADDR: HEXDUMP 256 BYTES OF MEMORY\N\R" 
            DB      "IN PORT: READ BYTE FROM I/O PORT\N\R" 
            DB      "JUMP ADDR: JUMP TO ADDRESS\N\R" 
;            DB      "MEMCPY DEST SRC NBYTES: COPY MEMORY\N\R" 
            DB      "MEMED ADDR: EDIT MEMORY\N\R" 
            DB      "OUT PORT VAL: WRITE BYTE TO I/O PORT\N\R" 
;            DB      "POP: POP FROM STACK\N\R" 
;            DB      "PUSH VAL: PUSH TO STACK\N\R" 
            DB      "REGISTERS: REGISTER DUMP\N\R" 
;            DB      "STACK: STACK TRACE\N\R" 
            DB      0 ;"\0"
; 
;--------------------------------------------

JUMP:                
            LD      A,(MON_ARGC) 
            CP      1 
            JR      Z,JUMP00 
; ARGC ERROR
            LD      HL,JUMPSTR 
            JP      ONEMEMADDRESSARGCERROR 
JUMP00:              
            LD      HL,(MON_ARGV) 
            CALL    VALIDATEADDRESS 
            JR      Z,JUMP01 
            RET      
JUMP01:              
            CALL    READ16BIT 
            LD      H,B 
            LD      L,C 
            JP      (HL) 

;--------------------------------------------

;MEMCPY:              
     

;EXPECTSEXACTLYTHREEARGSSTR:  
;            DB      " EXPECTS EXACTLY THREE ARGS \R\N",0 
;CFLOADARGSTR:        
;            DB      "(MEM ADDRESS, START SECTOR, SECTOR COUNT)\R\N",0 
; 
;--------------------------------------------

MEMED:               
            LD      A,(MON_ARGC) 
            CP      1 
            JR      Z,MEMED00 
; ARGC ERROR
            LD      HL,MEMEDSTR 
            JP      ONEMEMADDRESSARGCERROR 
            RET      
MEMED00:             
; VALIDATE, PARSE AND PUSH DESTINATION
            LD      HL,(MON_ARGV) 
            CALL    VALIDATEADDRESS 
            RET     NZ 
            CALL    READ16BIT 
            LD      D,B 
            LD      E,C 
MEMED01:             
            LD      HL,MON_LINEBUF 
            LD      A,D 
            CALL    STRFHEX 
            LD      A,E 
            CALL    STRFHEX 
            LD      (HL),"\T" 
            INC     HL 
            LD      A,(DE) 
            CALL    STRFHEX 
            LD      (HL)," " 
            INC     HL 
            LD      (HL),$0 
            LD      HL,MON_LINEBUF 
            CALL    PRINTSTRINGA 
            CALL    READLINEA 
            RET     NZ ; USER HIT CTRL-C
            LD      A,(HL) 
            CP      $0 
            JR      Z,MEMED02 
            CALL    CONVERTTOUPPER 
            CALL    VALIDATEVALUE 
            JR      NZ,MEMED01 
            PUSH    DE 
            CALL    READ8BIT 
            POP     DE 
            LD      (DE),A 
MEMED02:             
            INC     DE 
            JR      MEMED01 
; 
;--------------------------------------------

REGISTERS:           
            LD      HL,REG_LABELS 
            CALL    PRINTSTRINGA 
            LD      DE,MON_STACK 
            LD      B,8 
            CALL    REGISTERPRINT 

            LD      HL,ALT_REG_LABELS 
            CALL    PRINTSTRINGA 
            LD      B,8 
            CALL    REGISTERPRINT 

            LD      HL,I_REG_LABELS 
            CALL    PRINTSTRINGA 
            LD      B,4 
            CALL    REGISTERPRINT 

            RET      
; 
REGISTERPRINT:       
            LD      HL,MON_LINEBUF 
REGISTERPRINTLOOP:   
            LD      A,(DE) 
            DEC     DE 
            CALL    STRFHEX 
            LD      (HL)," " 
            INC     HL 
            DJNZ    REGISTERPRINTLOOP 
            CALL    TERMINATELINE 
            LD      HL,MON_LINEBUF 
            CALL    PRINTSTRINGA 
            RET      

REG_LABELS:          
            DB      "A  F  B  C  D  E  H  L\R\N",0 
ALT_REG_LABELS:      
            DB      "A' F' B' C' D' E' H' L'\R\N",0 
I_REG_LABELS:        
            DB      "IX    IY\R\N",0 

;--------------------------------------------

OUT:                 
            LD      A,(MON_ARGC) 
            CP      2 
            JR      Z,OUTVALIDATE 
; ARGC ERROR
            LD      HL,OUTSTR 
            LD      DE,EXPECTSEXACTLYTWOARGSSTR 
            LD      BC,OUTARGSSTR 
            JP      PRINT3STRINGS 
OUTARGSSTR:          
            DB      "(PORT, VALUE).\R\N",0 
OUTVALIDATE:         
            LD      HL,(MON_ARGV) 
            CALL    VALIDATEVALUE 
            RET     NZ 
            LD      HL,(MON_ARGV+2) 
            CALL    VALIDATEVALUE 
            RET     NZ 
            LD      HL,(MON_ARGV) 
            CALL    READ8BIT 
            LD      C,A 
            PUSH    BC 
            LD      HL,(MON_ARGV+2) 
            CALL    READ8BIT 
            POP     BC 
            OUT     (C),A 
            RET      

EXPECTSEXACTLYTWOARGSSTR:  
            DB      " EXPECTS EXACTLY TWO ARGS ",0 
;--------------------------------------------


WHAT:                
            LD      HL,WHATSTR 
            CALL    PRINTSTRINGA 
            RET      

WHATSTR:    DB      "WHAT?\N\R",0 

; --------------------------------------------
; 
; CLI
; 
; --------------------------------------------

PARSELINE:           
; 
; BC IS A POINTER TO THE ARGC/ARGV ARRAY
;	(IT GETS PUSHED AND POPPED AROUND COMPARISONS)
; DE IS USED BY STRTOK
; HL IS A POINTER TO THE LINE TO PARSE
; 
; PREPARE TO READ ARGUMENTS
; SET ARGC TO 0
            PUSH    HL ; KEEP STRING POINTER
            PUSH    BC ; KEEP START OF ARGCV STRUCT
            INC     BC ; SKIP COUNTER
            LD      A,0 
            PUSH    AF ; KEEP ARG COUNT ON STACK
PARSELINE00:         
            CALL    STRTOK 
; IF STRING ENDED IN A NULL, WE'RE DONE
            CP      0 ;"\0" 
            JR      Z,PARSELINE01 
; DE NOW POINTS TO THE START OF THE FIRST ARG
; LOAD THIS INTO (BC) AND INCREMENT
            LD      A,E 
            LD      (BC),A 
            INC     BC 
            LD      A,D 
            LD      (BC),A 
            INC     BC 
; INCREMENT ARGC
            POP     AF 
            INC     A 
            PUSH    AF 
; PREPARE FOR NEXT STRTOK...
            EX      DE,HL 
            JR      PARSELINE00 
PARSELINE01:         
            POP     AF ; GET ARG COUNT
            POP     BC ; SET BC BACK TO START OF ARGCV
            LD      (BC),A ; STORE ARGC
            POP     HL ; GET STRING POINTER BACK
            RET      

MAPSTRING2ADDRESS:   
; IN:
; HL POINTS TO A STRING
; BC POINTS TO TABLE OF (STRING ADDRESS, ARB ADDRESS) PAIRS
; THE TABLE MUST BE TERMINATED WITH A POINTER TO A NULL STR,
; WHICH ACTS AS A DEFAULT MATCH
; THIS FUNCTION WRITES THE MATCHING ARB ADDRESS INTO HL
            LD      A,(BC) 
            LD      E,A 
            INC     BC 
            LD      A,(BC) 
            LD      D,A 
            INC     BC 
            PUSH    BC 
            PUSH    HL 
            CALL    STRCMP 
            POP     HL 
            POP     BC 
            JR      Z,MAPS2A01 ; WE'VE MATCHED!
            INC     BC 
            INC     BC 
            JR      MAPSTRING2ADDRESS 
MAPS2A01:            
            LD      A,(BC) 
            LD      L,A 
            INC     BC 
            LD      A,(BC) 
            LD      H,A 
            RET      

; FUNCTION WHICH INTERPRETS THE STRING POINTED TO BY HL
; AS A COMMAND AND CALLS THE APPROPRIATE FUNCTION
DISPATCH:            
            CALL    MAPSTRING2ADDRESS 
            JP      (HL) 

HANDLECOMMANDLINE:   
; HL - COMMAND STRING POINTER
; DE - DISPATCH TABLE POINTER
; BC - ARGC/ARGV STRUCTURE
            CALL    SKIPWHITESPACE 
            CALL    CONVERTTOUPPER 
            PUSH    DE 
            CALL    PARSELINE 
            POP     BC 
            CALL    DISPATCH 
            RET      

; 
; 
; UTILITY FUNCTIONS
; 
; 

VALIDATEVALUE:       
            CALL    STRLEN 
            CP      2 
            JR      NZ,VALIDATEVALUEERROR 
            CALL    ISSTRHEX 
            JR      NZ,VALIDATEVALUEERROR 
            CP      A ; SET ZERO FLAG
            RET      
VALIDATEVALUEERROR:  
            CALL    PRINTSTRINGA 
            LD      HL,ISNOTAVALIDSTR 
            CALL    PRINTSTRINGA 
            LD      HL,VALUEERRORSTR 
            CALL    PRINTSTRINGA 
            OR      1 ; RESET ZERO FLAG
            RET      
ISNOTAVALIDSTR:      
            DB      " IS NOT A VALID ",0 
VALUEERRORSTR:       
            DB      "VALUE (USE 00-FF).\R\N",0 

VALIDATEADDRESS:     
            CALL    STRLEN 
            CP      4 
            JR      NZ,VALIDATEADDRESSERROR 
            CALL    ISSTRHEX 
            JR      NZ,VALIDATEADDRESSERROR 
            CP      A ; SET ZERO FLAG
            RET      
VALIDATEADDRESSERROR:  
            CALL    PRINTSTRINGA 
            LD      HL,ISNOTAVALIDSTR 
            CALL    PRINTSTRINGA 
            LD      HL,ADDRESSERRORSTR 
            CALL    PRINTSTRINGA 
            OR      1 ; RESET ZERO FLAG
            RET      
ADDRESSERRORSTR:     
            DB      "ADDRESS (USE 0000-FFFF).\R\N",0 



; 
; .MONROMDATA
; 

            ORG    MONROMDATA 
STR_ZTMON:  DB      "ZT80MON\N\R",0 
STR_ZTMVER: DB      "V0.003\N\R",0 

; 
; .MONRAMDATA
; 
            ORG    MONRAMDATA 
;CLI_LINE_BUF:    DS CLI_LINE_MAX
;CLI_LINE_PTR:    DW CLI_LINE_BUF


; STUFF FOR THE MONITOR
START_MON_RAM:       
MON_LINEBUF: DS     80 
MON_ARGC:   DS      1 
MON_ARGV:   DS      2 
            DS      40 
MON_STACK:  DS      2 
MON_STACK_BACKUP: DS 2 
END_MON_RAM:         

MESSAGE_BUFFER: DS  80 

; BIN2DEC
B2DINV:     DS      8 ; SPACE FOR 64-BIT INPUT VALUE (LSB FIRST)
B2DBUF:     DS      20 ; SPACE FOR 20 DECIMAL DIGITS
B2DEND:     DS      1 ; SPACE FOR TERMINATING 0

