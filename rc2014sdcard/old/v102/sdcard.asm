;
; SD card load, save, del, and list demo
;
; uses de scm api to print and get user input
;
; v1.0   - load and save 
; v1.0a  - dir added
; v1.0b  - remove added
; v1.0c  - debug output commented
; v1.0c1 - convert from asm80.com to z80asm (just one line)
;        - dont worked with org defined for rodata
; v1.01  - store on memory num bytes loaded
; v1.02 - jump table at the beguin
;          delayde, new routine used on read file
;          equ for sdcard commands


                    ORG   $8000   
;                    ORG   $2000

                    ; sdcard io addresses
SDCRS:              EQU   0x40   
SDCRD:              EQU   0x41   
SDCWC:              EQU   0x40   
SDCWD:              EQU   0x41   
                    ; sdcard io status
SDCSIDL:            EQU   0x00   
SDCSWFN:            EQU   0x02   
SDCSWFD:            EQU   0x04
SDCSRFN:            EQU   0x03   
SDCSRFD:            EQU   0x05
SDCSDIR:            EQU   0x10
SDCSDFN:            EQU   0x20

                    ; sdcard io commands
SDCMDRESET:          EQU   0x0f
SDCMDLOAD:           EQU   0x0d
SDCMDSAVE:           EQU   0x0c
SDCMDWRITE:          EQU   0x
SDCMDWREND:          EQU   0x0b
SDCMDLIST:           EQU   0x0e
SDCMDDEL:            EQU   0x0a

;
;
; try to mantain a stable
; address to calling routines
; api call jump table 
;
CLIENTRY:           jp MAIN
APISAVE:            jp STARTWFN
APILOAD:            jp STARTRFN
APIDEL:             jp STARTDFN
APILIST:            jp STARTLSTF
APIREN:             jp STARTRNFN
APICOPY:            jp STARTCPFN
APICHDIR:           jp STARTCDDN
APIMKDIR:           jp STARTMKDN
APIRMDIR:           jp STARTRMDN

; just info
MAIN:        
                    ; display start message
                    ; call api: print str
                    ld   de,STR_ZTGSDC
                    ld   c,$06
                    rst  $30   
                                        
                    ; display get cmd message
                    ; call api: print str
                    ld   de, STR_CMD
                    ld   C,$06
                    rst   $30 
                    
                    ; get cmd string from user
                    ; call api: get input
                    ld de, LINEBUF
                    ld a, $41 ; load string len + 1 (for terminator)
                    ld c, $04
                    rst   $30

                    ;
                    ; display label save filename

                    ; load string start address
                    ;ld   de,STR_LOAD
                    ; load api id
                    ;ld   C,$06
                    ; call api
                    ;rst   $30
                    
                    ;
                    ; display line buffer
                    ;
                    ; load string  start address
                    ;ld   de,LINEBUF
                    ; load api id
                    ;ld   C,$06
                    ; call api
                    ;rst   $30
                    
                    ; output nl & cr
                    ld a, '\n'
                    call OUTCHAR
                    ld a, '\r'
                    call OUTCHAR                    

                    call LINE_PARSE
                    
                    ;
                    ; dispatch cmd
                    ; by sequentialy 
                    ; compare hl with de
                    ; hl have the command
                    ; de have the input to be tested
                    
                    ld hl, CMD_DEL
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK1
                    
                    ; dispatch
                    call STARTDFN

                    jr MAIN_END
                    
MAIN_CHK1:
                    ld hl, CMD_LIST
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK2
                    
                    ; dispatch
                    call STARTLSTF
                    
                    jr MAIN_END

MAIN_CHK2:
                    ld hl, CMD_LOAD
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK3
                    
                    ; dispatch
                    call STARTRFN
                    
                    jr MAIN_END

MAIN_CHK3:
                    ld hl, CMD_SAVE
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_END
                    
                    ; dispatch
                    call STARTWFN

MAIN_END:
                    ret

;--------------------------------------------------------
;
; parse the command line
;
;--------------------------------------------------------

LINE_PARSE:
                    ; set hl to point to the start of cmd line buffer
                    ld hl, LINEBUF
                    ; hl pointer to current location on cli 
                    ; set de to the start of cmd string
                    ld de,FILE_CMD
                    call CLI_GETSTRARG
                    
                    ; convert cmd field to upper
                    push hl
                    ld hl, FILE_CMD
                    call CONVERTTOUPPER
                    pop hl
                    

                    ; hl pointer to current location on cli 
                    ; set de to the start of filename string
                    ld de,FILE_NAME
                    call CLI_GETSTRARG

                    ; hl pointer to current location on cli 
                    ; set de to the start of tmp string
                    ld de,LINETMP
                    call CLI_GETSTRARG

                    push hl
                    ;
                    ld hl,LINETMP
                    call CONVERTTOUPPER

                    call CLI_HEX2TBIN1
                    ld de, FILE_START
                    ld (de), a
                    ;
                    call CLI_HEX2TBIN1
                    ld de, FILE_START
                    inc de
                    ld (de), a                   
                    ;
                    pop hl
                    
                    ; hl pointer to current location on cli 
                    ; set de to the start of tmp string
                    ld de,LINETMP
                    call CLI_GETSTRARG
                    
                    push hl
                    ;
                    ld hl,LINETMP
                    call CONVERTTOUPPER

                    call CLI_HEX2TBIN1
                    ld de, FILE_LEN
                    ld (de), a
                    ;
                    call CLI_HEX2TBIN1
                    ld de, FILE_LEN
                    inc de
                    ld (de), a                   
                    ;
                    pop hl

                    ;push hl
                    ;
                    ; display string
                    ;ld   de, FILE_CMD
                    ; load api id
                    ;ld c,$06
                    ; call api
                    ;rst   $30
                    ;
                    ;pop hl
                    
                    ;ld a, '\n';
                    ;call OUTCHAR
                    ;ld a, '\r';
                    ;call OUTCHAR
                    
                    ;push hl
                    ;
                    ; display string
                    ;ld   de, FILE_NAME
                    ; load api id
                    ;ld c,$06
                    ; call api
                    ;rst   $30
                    ;
                    ;pop hl
                    
                    ;ld a, '\n';
                    ;call OUTCHAR
                    ;ld a, '\r';
                    ;call OUTCHAR

                    
LINE_PARSE_END:
                    ret


;--------------------------------------------

;
; get string from string by delimitator
;
; hl pointer to current location on cli
; de pointer to the destination location
; 
; ends if delimitor is found or string ends
CLI_GETSTRARG:
                    ; load a register with the contents of
                    ; address pointed by de register
                    ld  a,(hl)   
        
                    ; dbg
                    ;CALL OUTCHAR

                    ; check separator
                    cp  ' '
                    jr z, CLI_GETSTRARG_S

                    ; check eol
                    cp  0
                    ; is eol, store and return 
                    jr  z,CLI_GETSTRARG_E
                    
                    ld  (de), a
                    
                    inc hl
                    inc de
                    
                    jr CLI_GETSTRARG

CLI_GETSTRARG_S:
                    ; is separator
                    ; terminate filename string
                    ld a, 0
                    ld (de), a
                    inc hl
                    ret
CLI_GETSTRARG_E:
                    ; is eol
                    ; terminate filename string
                    ld a, 0
                    ld  (de), a
                    inc hl
                    ld a, 1
                    ret
 
;--------------------------------------------
;
; verify and convert 2 bytes ascii hex to numeric binany
; hl hl is pointer to start of ascii hex
; return A = 0 is ok, A = 1 error
;--------------------------------------------
CLI_HEX2TBIN1:
                    ; check for good hex
                    call ISSTRHEX
                    
                    ; check for bad argument
                    jr nz, GOT_BADHEX
                    
                    ; is good
                    jr GOT_OKHEX
                    
GOT_BADHEX:                   
                    ld a, 1
                    ret
                    
GOT_OKHEX:                    
                    ld a, 1
                    call HEX2NUM
                    ret

;--------------------------------------------------------
;
; Delete file from SD
;
;--------------------------------------------------------
STARTDFN:
                    ;ld   de,STR_CMD_DEL
                    ; load api id
                    ;ld   C,$06
                    ; call api
                    ;rst   $30
                    
                    
                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl
                    
                    ; get status
                    in   a,(SDCRS)   
                    ; exit with error message if a != 0
                    cp   SDCSIDL   
                    jr   z,STARTDFN_OK1 
; just info
STARTDFN_FAIL1:
                    ;
                    ; display error message
                    ;
                    ; load string start address
                    ld   de,STR_SDSTATUS_BAD
                    ; load api id
                    ld   C,$06
                    ; call api
                    rst   $30

                    ; return
                    ret

STARTDFN_OK1:
                    ;
                    ; display ok message
                    ;
                    ;ld   de,STR_SDSTATUS_OK
                    ; load api id
                    ;ld   C,$06
                    ; call api
                    ;rst   $30
                    
                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl


                    ; start delete file
                    ; load cmd code in a, see equs
                    ld   a,SDCMDDEL   
                    out   (SDCWC),a
                    
                    ;
                    ; display operation
                    ;
                    ; load string start address
                    ;ld   de,STR_CHK_NAME
                    ; load api id
                    ;ld   C,$06
                    ; call api
                    ;rst   $30

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl
                    ; get status
                    in   a,(SDCRS)   
                    ; if status != 32 exit
                    cp   SDCSDFN
                    jr   z,STARTDFN_OK2

                    
                    ;
                    ; display error message
                    ;
                    ; load string start address
                    ld   de,STR_SDSTATUS_BAD
                    ; load api id
                    ld   C,$06
                    ; call api
                    rst   $30

                    ; return                    
                    ret                     
                    
STARTDFN_OK2:
                    ;
                    ; ready to send the file name
                    ;
                    ; display ok message
                    ;
                    ;ld   de,STR_SDSTATUS_OK
                    ; load api id
                    ;ld   C,$06
                    ; call api
                    ;rst   $30
                    
                    ;
                    ; send the file name
                    ;
                    push bc
                    push hl
                    call SENDFNAME   
                    pop  hl
                    pop  bc


                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 10
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get status
                    in   a,(SDCRS)   
                    ; is rfile state ?
                    cp   SDCSIDL
                    jr   z, STARTDF_OK
                    
                    ;
                    ; display error message
                    ;
                    ; load string start address
                    ld   de,STR_SDSTATUS_BAD
                    ; load api id
                    ld   C,$06
                    ; call api
                    rst   $30
                    
                    ; return
                    ret
                    
STARTDF_OK:                    
                    ;
                    ; display end message
                    ;
                    ld   de,STR_REMOK
                    ; load api id
                    ld   C,$06
                    ; call api
                    rst   $30


                    ret
                    
;--------------------------------------------------------
;
; List files on SD
;
;--------------------------------------------------------
STARTLSTF:
                    ;ld   de,STR_CMD_LIST
                    ; load api id
                    ;ld   C,$06
                    ; call api
                    ;rst   $30

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl
                    
                    ; get status
                    in   a,(SDCRS)   
                    ; exit with error message if a != 0
                    cp   SDCSIDL   
                    jr   z,STARTLSTF_OK1 
; just info
STARTLSTF_FAIL1:
                    ;
                    ; display error message
                    ;
                    ; load string start address
                    ld   de,STR_SDSTATUS_BAD
                    ; load api id
                    ld   C,$06
                    ; call api
                    rst   $30

                    ; return
                    ret

STARTLSTF_OK1:
                    ;
                    ; display ok message
                    ;
                    ;ld   de,STR_SDSTATUS_OK
                    ; load api id
                    ;ld   C,$06
                    ; call api
                    ;rst   $30
                    
                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; start directory list
                    ; load cmd code in a, see equs
                    ld   a,SDCMDLIST   
                    out   (SDCWC),a
                    
                    ;
                    ; display operation
                    ;
                    ; load string start address
                    ;ld   de,STR_CHK_NAME
                    ; load api id
                    ;ld   C,$06
                    ; call api
                    ;rst   $30

                    ; wait many ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 100
                    ld  c, $0a
                    rst $30
                    pop hl
                    
DIRLISTLOOP:
                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl
                    
                    ; check if we have
                    ; any byte available

                    ; get status
                    in   a,(SDCRS)
                    
                    ; display status
                    ;call OUTCHAR
                    ;push af
                    ; output nl & cr
                    ;ld a, '\n'
                    ;call OUTCHAR
                    ;ld a, '\r'
                    ;call OUTCHAR
                    ;pop af
                    
                    ; return if its not in dir list state
                    cp   SDCSDIR                     
  
                    ; directory listed
                    jr  nz, ENDDIR_OK
                    
                    ; wait 1 ms before any
                    ; in or out to SD card
                    ;push bc
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl
                    ;pop bc 
                    
                    ; get data
                    in   a,(SDCRD)
                    
                    ; display char
                    call OUTCHAR                    
                    
                    jr DIRLISTLOOP
                      
                    
ENDDIR_OK:
                    ; directory was listed
                    ;
                    ; display end message
                    ;
                    ld   de,STR_DIROK
                    ; load api id
                    ld   C,$06
                    ; call api
                    rst   $30
                    
                    ; return
                    ret

;--------------------------------------------------------
;
; Save file to SD
;
;--------------------------------------------------------
STARTWFN:
                    ;
                    ; display operation
                    ;
                    ; load string start address
                    ;ld   de,STR_CHK_IDLE
                    ; load api id
                    ;ld   C,$06
                    ; call api
                    ;rst   $30
                    
                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl
                    
                    ; get status
                    in   a,(SDCRS)   
                    ; exit with error message if a != 0
                    cp   SDCSIDL   
                    jr   z,STARTWFN_OK1 
; just info
STARTWFN_FAIL1:
                    ;
                    ; display error message
                    ;
                    ; load string start address
                    ld   de,STR_SDSTATUS_BAD
                    ; load api id
                    ld   C,$06
                    ; call api
                    rst   $30

                    ; return
                    ret

STARTWFN_OK1:
                    ;
                    ; display ok message
                    ;
                    ;ld   de,STR_SDSTATUS_OK
                    ; load api id
                    ;ld   C,$06
                    ; call api
                    ;rst   $30
                    
                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; start save file process
                    ; load cmd code in a, see equs
                    ld   a,SDCMDSAVE   
                    out   (SDCWC),a
                    
                    ;
                    ; display operation
                    ;
                    ; load string start address
                    ;ld   de,STR_CHK_NAME
                    ; load api id
                    ;ld   C,$06
                    ; call api
                    ;rst   $30
                    
                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; get status
                    in   a,(SDCRS)   
                    ; if status != 3 exit
                    cp   SDCSWFN
                    jr   z,STARTWFN_OK2
                    
                    ;
                    ; display error message
                    ;
                    ; load string start address
                    ld   de,STR_SDSTATUS_BAD
                    ; load api id
                    ld   C,$06
                    ; call api
                    rst   $30

                    ; return                    
                    ret                     
                    
STARTWFN_OK2:
                    ;
                    ; ready to send the file name
                    ;
                    ; display ok message
                    ;
                    ;ld   de,STR_SDSTATUS_OK
                    ; load api id
                    ;ld   C,$06
                    ; call api
                    ;rst   $30
                    
                    ;
                    ; send the file name
                    ;
                    push    bc
                    push    hl
                    call    SENDFNAME   
                    pop     hl
                    pop     bc
                    
; just info
STARTWFD:      
                    ;
                    ; display operation
                    ;
                    ; load string start address
                    ;ld   de,STR_CHK_FILE
                    ; load api id
                    ;ld   C,$06
                    ; call api
                    ;rst   $30

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; get status
                    in   a,(SDCRS)   
                    ; return if its not wfile state
                    cp   SDCSWFD   
                    jr   z, STARTWFD_OK
                    
                    ;
                    ; display error message
                    ;
                    ; load string start address
                    ld   de,STR_SDSTATUS_BAD
                    ; load api id
                    ld   C,$06
                    ; call api
                    rst   $30
                    ; return
                    ret

STARTWFD_OK:
                    ;
                    ; display ok message
                    ;
                    ;ld   de,STR_SDSTATUS_OK
                    ; load api id
                    ;ld   C,$06
                    ; call api
                    ;rst   $30
                    
                    ; point hl to start of memory
                    ;ld   hl,PRGADDR
                    ld hl,FILE_START
                    ld d, (hl)
                    inc hl
                    ld e, (hl)
                    ; need to get de in hl
                    ld h, d
                    ld l, e


                    ;ld b,PRGLEN
                    push hl
                    ;
                    ld hl,FILE_LEN
                    ld d, (hl)
                    inc hl
                    ld e, (hl)
                    ;
                    pop hl
                    
                    
                    ld   c,SDCWD 
                    
WFDLOOPADDR:      
                    ; wait 1 ms before any
                    ; in or out to SD card
                    push de
                    push bc
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl
                    pop bc
                    pop de

                    ; output one memory byte
                    outi
                    
                    ; control if its over
                    dec de
                    
                    ; check if bc is zero
                    ;push a
                    ld a, d
                    or e
                    ;pop a
                    
                    ; not zero
                    jr   nz,WFDLOOPADDR 
                    
                    
                    ; wait 1 ms before any
                    ; in or out to SD card
                    ;push de
                    push bc
                    push hl
                    ld de, 1
                    ld c, $0a
                    rst $30
                    pop hl
                    pop bc
                    ;pop de

                    ; end file write
                    ; load cmd code in a, see equs
                    ld   a,SDCMDWREND ;0x0b   
                    out  (SDCWC),a   

; just info
ENDWFD:
                    ; wait 1 ms before any
                    ; in or out to SD card
                    ;push de
                    push bc
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl
                    pop bc
                    ;pop de

                    ; get status
                    in   a,(SDCRS)   
                    ; if ok its idle state
                    cp   SDCSIDL   
                    jr   z,ENDWFD_OK                    

                    ;
                    ; display error message
                    ;
                    ld   de,STR_ERROR
                    ; load api id
                    ld   C,$06
                    ; call api
                    rst   $30

                    ; return
                    ret

ENDWFD_OK:                    
                    ; the file is loaded
                    ;
                    ; display end message
                    ;
                    ld   de,STR_SAVEOK
                    ; load api id
                    ld   C,$06
                    ; call api
                    rst   $30
                    
                    ; return
                    ret

                    
;--------------------------------------------------------
;
; Load file from SD
;
;--------------------------------------------------------

STARTRFN:
                    ;
                    ; display operation
                    ;
                    ; load string start address
                    ;ld   de,STR_CHK_IDLE
                    ; load api id
                    ;ld   C,$06
                    ; call api
                    ;rst   $30
                    
                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl
                    
                    ; get status
                    in   a,(SDCRS)   
                    ; exit with error message if a != 0
                    cp   SDCSIDL   
                    jr   z,STARTRFN_OK1 
; just info
STARTRFN_FAIL1:
                    ;
                    ; display error message
                    ;
                    ; load string start address
                    ld   de,STR_SDSTATUS_BAD
                    ; load api id
                    ld   C,$06
                    ; call api
                    rst   $30

                    ; return
                    ret

STARTRFN_OK1:
                    ;
                    ; display ok message
                    ;
                    ;ld   de,STR_SDSTATUS_OK
                    ; load api id
                    ;ld   C,$06
                    ; call api
                    ;rst   $30
                    
                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; start load file
                    ; load cmd code in a, see equs
                    ld   a,SDCMDLOAD ; 0x0d   
                    out   (SDCWC),a
                    
                    ;
                    ; display operation
                    ;
                    ; load string start address
                    ;ld   de,STR_CHK_NAME
                    ; load api id
                    ;ld   C,$06
                    ; call api
                    ;rst   $30

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl
                    ; get status
                    in   a,(SDCRS)   
                    ; if status != 3 exit
                    cp   SDCSRFN
                    jr   z,STARTRFN_OK2
                    
                    ;
                    ; display error message
                    ;
                    ; load string start address
                    ld   de,STR_SDSTATUS_BAD
                    ; load api id
                    ld   C,$06
                    ; call api
                    rst   $30

                    ; return                    
                    ret                     
                    
STARTRFN_OK2:
                    ;
                    ; ready to send the file name
                    ;
                    ; display ok message
                    ;
                    ;ld   de,STR_SDSTATUS_OK
                    ; load api id
                    ;ld   C,$06
                    ; call api
                    ;rst   $30
                    
                    ;
                    ; send the file name
                    ;
                    push bc
                    push hl
                    call SENDFNAME   
                    pop  hl
                    pop  bc
                    
; just info
STARTRFD:      
                    ;
                    ; display operation
                    ;
                    ; load string start address
                    ;ld   de,STR_CHK_FILE
                    ; load api id
                    ;ld   C,$06
                    ; call api
                    ;rst   $30

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get status
                    in   a,(SDCRS)   
                    ; is rfile state ?
                    cp   SDCSRFD
                    jr   z, STARTRFD_OK
                    
                    ;
                    ; display error message
                    ;
                    ; load string start address
                    ld   de,STR_SDSTATUS_BAD
                    ; load api id
                    ld   C,$06
                    ; call api
                    rst   $30
                    
                    ; return
                    ret
                    
STARTRFD_OK:                    
                    ; ready to load the file data
                    ;
                    ; display ok message
                    ;
                    ;ld   de,STR_SDSTATUS_OK
                    ; load api id
                    ;ld   C,$06
                    ; call api
                    ;rst   $30
                    
                    ; point hl to start of memory
                    ld hl,FILE_START
                    ld d, (hl)
                    inc hl
                    ld e, (hl)
                    ; need to get de in hl
                    ld h, d
                    ld l, e
                    
                    ld de, 0x0000
RFDLOOPADDR:      
                    ; wait 1 ms before any
                    ; in or out to SD card
                    ;;push bc
                    ;push hl
                    ;push de
                    ;ld  de, 1
                    ;ld  c, $0a
                    ;rst $30
                    ;pop de
                    ;pop hl
                    ;;pop bc

                    push de
                    ld de,0x00ff
                    call DELAYDE
                    pop de

                    ; check if we have
                    ; any byte available

                    ; get status
                    in   a,(SDCRS)
                                        
                    ; display status
                    ;call OUTCHAR
                    ;push af
                    ; output nl & cr
                    ;ld a, '\n'
                    ;call OUTCHAR
                    ;ld a, '\r'
                    ;call OUTCHAR
                    ;pop af
                    
                    ; return if its not rfile state
                    cp   SDCSRFD   
                    ; the file is loaded
                    jr  nz, ENDRFD_OK   
                    ;

                    ; wait 1 ms before any
                    ; in or out to SD card
                    ;;push bc
                    ;push hl
                    ;push de
                    ;ld  de, 1
                    ;ld  c, $0a
                    ;rst $30
                    ;pop de
                    ;pop hl
                    ;pop bc

                    push de
                    ld de,0x00ff
                    call DELAYDE
                    pop de

                    ; increment bytes loaded counter
                    inc de

                    ; b will be decremented
                    ; never gave problems with
                    ; out this line. Let see now.
                    ld b, 0xff

                    ; get one memory byte
                    ; c have the SDC address for WD
                    ld   c,SDCWD 
                    ini
                    jr   nz,RFDLOOPADDR 

ENDRFD_OK:
                    ; the file is loaded
                    ;

                    ; store num bytes loaded
                    push hl
                    ld hl, NUM_BYTES
                    ld (hl),d
                    inc hl
                    ld (hl),e
                    pop hl

                    ; display end message
                    ;
                    ld   de,STR_LOADOK
                    ; load api id
                    ld   C,$06
                    ; call api
                    rst   $30
                    
                    ; return
                    ret

;--------------------------------------------------------
;
; Rename file on SD
;
;--------------------------------------------------------
STARTRNFN:
                        ret
;--------------------------------------------------------
;
; Copy file on SD
;
;--------------------------------------------------------
STARTCPFN:
                        ret
;--------------------------------------------------------
;
; CD on SD
;
;--------------------------------------------------------
STARTCDDN:
                        ret
;--------------------------------------------------------
;
; Make directory on SD (mkdir)
;
;--------------------------------------------------------
STARTMKDN:
                        ret
;--------------------------------------------------------
;
; Remove directory on SD (mkdir)
;
;--------------------------------------------------------
STARTRMDN:
                        ret
;--------------------------------------------------------
; 
; send file name or directory name
;
; todo 
; input: hl with pointer to string name.
; then can be used in a generic way
;
;--------------------------------------------------------

SENDFNAME:      
                    ; point hl to start of string
                    ld   hl,FILE_NAME   
SFNLOOPCHAR:      
                    ; load a register with the contents of
                    ; address pointed by hl register
                    ld   a,(Hl)   

                    ; print the char using scm api
                    ; we got the chat to print in
                    ; register a
                    ; we need to place the api id 2
                    ; (print char) on register c
                    ;CALL    OUTCHAR
                    
                    ; wait 1 ms before any
                    ; in or out to SD card
                    push af
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl
                    pop af

                    ; send char to sdc io
                    out (SDCWD),a
                    
                    ; check if the its is "\0"
                    cp   $00
                    ; return if it is
                    ret   z 

                    inc hl   
                    jr  SFNLOOPCHAR

;--------------------------------------------
; 
; STRINGS
; 
;--------------------------------------------

STRCMP:
            LD      a,(hl) 
            CP      $0 
            RET     z 
            LD      b,a 
            LD      a,(de) 
            CP      $0 
            RET     z 
            CP      b 
            RET     nz 
            INC     hl 
            INC     de 
            JR      STRCMP 

;--------------------------------------------


CONVERTTOUPPER:      
                    PUSH    hl 
CONVERTTOUPPER00:    
                    LD      a,(hl) 
                    CP      $0 
                    JR      z,CONVERTTOUPPER03 
                    CP      "a" 
                    JR      z,CONVERTTOUPPER01 
                    JR      c,CONVERTTOUPPER02 
                    CP      "z" 
                    JR      z,CONVERTTOUPPER01 
                    JR      nc,CONVERTTOUPPER02 
CONVERTTOUPPER01:    
                    SUB     32 
                    LD      (hl),a 
CONVERTTOUPPER02:    
                    INC     hl 
                    JR      CONVERTTOUPPER00 
CONVERTTOUPPER03:    
                    POP     hl 
                    RET   

;--------------------------------------------


ISSTRHEX:            
            PUSH    hl 
ISSTRHEX00:          
            LD      a,(hl) 
; Test for end of string
            CP      0 ;"\0"
            JR      z,ISSTRHEXTRUE 
; Fail if < "0"
            CP      "0" 
            JR      c,ISSTRHEXFALSE 
; Continue if <= "9" (< "9"+1)
            CP      "9"+1 
            JR      c,ISSTRHEXCONTINUE 
; Fail if < "A"
            CP      "0" 
            JR      c,ISSTRHEXFALSE 
; Continue if <= "F" (< "F"+1)
            CP      "F"+1 
            JR      c,ISSTRHEXCONTINUE 
; Fall through to fail otherwise
ISSTRHEXFALSE:       
            OR      1 ; Reset zero flag
            POP     hl 
            RET      
ISSTRHEXTRUE:        
            CP      a ; Set zero flag
            POP     hl 
            RET      
ISSTRHEXCONTINUE:    
            INC     hl 
            JR      ISSTRHEX00 

;--------------------------------------------

;
; Convert ascii hex to number in binaRy

; HL is a pointer to a two-char string
; This is read as an 8 bit hex number
; The number is stored in A
HEX2NUM:             
        ;
                    LD      a,(hl) ; Copy first char to A
                    CALL    HEX2NUM1 ; Convert first char
                    ADD     a,a ; Multiply by 16...
                    ADD     a,a ; ...
                    ADD     a,a ; ...
                    ADD     a,a ; ...done!
                    LD      d,a ; Store top 4 bits in D
                    INC     hl ; Advance to next char
                    LD      a,(hl) 
                    CALL    HEX2NUM1 ; Convert second char
                    OR      d ; Add back top bits
                    INC     hl ; Advance for next guy
                    RET      
HEX2NUM1:           SUB     "0" 
                    CP      10 
                    RET     c 
                    SUB     "A"-"0"-10 
                    RET      

;--------------------------------------------

OUTCHAR:      
                    ; print char on
                    ; register A
                    push    bc
                    ;push    de
                    push    hl
                    ld      c,$02   
                    rst     $30   
                    pop     hl
                    ;pop     de
                    pop     bc
                    ret

;--------------------------------------------

;--------------------------------------------
;
; delay (input: de)
;
;--------------------------------------------

DELAYDE:
                        dec de
                        ld a,d
                        or e
                        jr nz,DELAYDE
                        ret

; 
; 
; 
                    ; removed converting from 
                    ; asmz80.com to z80asm
                    ;ORG    $8350
ROMDATA:
STR_ZTGSDC:         DB      "ZeTuGa80 SD CARD\n\r",0
STR_OK:             DB      "OK\n\r",0
STR_ERROR:          DB      "ERROR\n\r",0

STR_CMD:             DB      "CMD: ",0
;STR_CMD_LOAD        DB      "LOAD: ",0
;STR_CMD_SAVE        DB      "SAVE: ",0
;STR_CMD_DEL         DB      "DEL: ",0
;STR_CMD_LIST        DB      "LIST",0

;STR_LOAD:           DB      "Loading: ",0
;STR_SAVE:           DB      "Saving: ",0

STR_SDSTATUS_BAD:   DB      "Error: bad SD card if status\n\r",0
;STR_SDSTATUS_OK:    DB      "OK: SD card if status is good\n\r",0

;STR_CHK_IDLE:       DB      "Check for idle state\n\r",0
;STR_CHK_NAME:       DB      "Check for name state\n\r",0
;STR_CHK_FILE:       DB      "Check for file state\n\r",0

STR_LOADOK:         DB      "File loaded\n\r",0
STR_SAVEOK:         DB      "File saved\n\r",0
STR_DIROK:          DB      "List end!\n\r",0
STR_REMOK:          DB      "File removed\n\r",0

CMD_LOAD:            DB      "LOAD",0
CMD_SAVE:            DB      "SAVE",0
CMD_DEL:             DB      "DEL",0
CMD_LIST:            DB      "LIST",0


;                    ORG    $83E0
                    ORG    $FAE0
RAMDATA:
NUM_BYTES:          DS $02 ; 2 bytes
FILE_START:         DS $02 ; 2 bytes
FILE_LEN:           DS $02 ; 2 bytes
FILE_CMD:           DS $10 ; 16 bytes
FILE_NAME:          DS $21 ; 33 bytes
FILE_NAME2:         DS $21 ; 33 bytes
LINETMP:            DS $41 ; 65 bytes
LINEBUF:            DS $81 ; 129 bytes
