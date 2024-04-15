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
; v1.02  - jump table at the beguin
;          delayde, new routine used on read file
;          equ for sdcard commands
; v1.03  - sdcard firmware status code changed
;          stm32 firmware ztgsdcard2 v1.01
; v1.04a - add rename
; v1.04b - add copy, strange behavior on list after one copy. 
;          stm32 crash on list. need to del (on cli) the new copied file
; v1.04c - add mkdir & rmdir. stm32 still crash on list
; v1.04d - add a litle more time to wait for list generation
;          stm32 firmware v1.04 dont crash on list
; v1.04e - add cd (change directory)
; v1.04f - add cwd (get current working directory full path name)
;        - add loop for the cli (require enter "exit" to return to SCM)
; v1.04g - add reset (reset the sd card interface, same as "o 40 f")
; v1.04h - add exist (check if file exists) (0 = no exist, 1 = file, 2 = dir)
; v1.04i - add sdstatus (get status code of the sd card interface)
; v1.04j - change list (add directory as argument)
;        - fix error when just return is pressed
; v1.05a - add fileopen & fileclose, fix bug on cmd del call
; v1.05b - add fwrite byte (write a byte in a open file giving his hdl (id)
; v1.05c - add read byte (read a byte in a open file giving his hdl (id)
; v1.05d - add fgetpos
; v1.05e - add seekset
; v1.05f - add seekcur & seekend
; v1.05g - add rewind
;
;         
;
                    ORG   $8000   
;                    ORG   $2000

; sdcard io addresses
SDCRS:              EQU   0x40   
SDCRD:              EQU   0x41   
SDCWC:              EQU   0x40   
SDCWD:              EQU   0x41 

; sdcard io status
SDCSIDL:            EQU   0x00 ;  
SDCSWFN:            EQU   0x10 ; write file, send name 
SDCSWFD:            EQU   0x12 ; write file, send data
SDCSRFN:            EQU   0x08 ; read file, send name 
SDCSRFD:            EQU   0x0a ; read file, read data
SDCSDIRFN:          EQU   0x20 ; list send name ('\0' is current dir)
SDCSDIR:            EQU   0x22 ; read list data
SDCSDFN:            EQU   0x28 ; delete file, send name
SDCSRENFN1:         EQU   0x30 ; rename, send source 
SDCSRENFN2:         EQU   0x38 ; rename, send dest
SDCSCPYFN1:         EQU   0x40 ; copy, send source 
SDCSCPYFN2:         EQU   0x48 ; copy, send dest
SDCSEXISFN:         EQU   0x80 ; exist file?, send name 
SDCSEXIST:          EQU   0x82 ; exist file?, read data 
SDCSMKDFN:          EQU   0x50 ; mkdir, send name
SDCSRMDFN:          EQU   0x58 ; rmdir, send name
SDCSCHDFN:          EQU   0x78 ; chdir, send name
SDCSCWD:            EQU   0x98 ; cwd, read data (full path name)
SDCSFOFN:           EQU   0xa0 ;
SDCSFOFM:           EQU   0xa8 ;
SDCSCFOGH:          EQU   0xb0 ;
SDCSFOIDL:          EQU   0xb2 ;
SDCSCFHDL:          EQU   0xb8 ;
SDCSFWHDL:          EQU   0xc0 ;
SDCSFWRITE:         EQU   0xc2 ;
SDCSFWSTAT:         EQU   0xc4 ;
SDCSFRHDL:          EQU   0xc8 ;
SDCSFREAD:          EQU   0xca ;
SDCSFRSTAT:         EQU   0xcc ;
SDCSFGPHDL:         EQU   0xd0 ;
SDCSFGPOS:          EQU   0xd2 ;
SDCSFSSHDL:         EQU   0xd8 ;
SDCSSEKSET:         EQU   0xda ;
SDCSFSSSTAT:        EQU   0xdc ;
SDCSFSCHDL:         EQU   0xe0 ;
SDCSSEKCUR:         EQU   0xe2 ;
SDCSFSCSTAT:        EQU   0xe4 ;
SDCSFSEHDL:         EQU   0xe8 ;
SDCSSEKEND:         EQU   0xea ;
SDCSFSESTAT:        EQU   0xec ;
SDCSFRWDHDL:        EQU   0xee ;

; sdcard io commands start
SDCMDRESET:          EQU   0x0f
SDCMDLOAD:           EQU   0x0d
SDCMDSAVE:           EQU   0x0c
;SDCMDWRITE:          EQU   0x
SDCMDWREND:          EQU   0x0b
SDCMDLIST:           EQU   0x0e
SDCMDDEL:            EQU   0x0a
SDCMDREN:            EQU   0x10
SDCMDCOPY:           EQU   0x11
SDCMDEXIST:          EQU   0x12
SDCMDMKDIR:          EQU   0x13
SDCMDRMDIR:          EQU   0x14
SDCMDCD:             EQU   0x15
SDCMDCWD:            EQU   0x16
SDCMDFOPEN:          EQU   0x20
SDCMDFCLOSE:         EQU   0x21
SDCMDFWRITE:         EQU   0x22
SDCMDFREAD:          EQU   0x23
SDCMDFGPOS:          EQU   0x24
SDCMDFSEKSET:        EQU   0x25
SDCMDFSEKCUR:        EQU   0x26
SDCMDFSEKEND:        EQU   0x27
SDCMDFREWIND:        EQU   0x28

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
APICWD:             jp STARTCWDN
APIMKDIR:           jp STARTMKDN
APIRMDIR:           jp STARTRMDN
APIEXIST:           jp STARTEXFN
;APIRESET:           jp STARTRESET
APIFOPEN:           jp STARTFOFN
APIFCLOSE:          jp STARTFCFH
APIFWRITE:          jp STARTFWFH
APIFREAD:           jp STARTFRFH
APIFGPOS:           jp STARTFGPFH
APIFSEEKSET:        jp STARTFSSFH
APIFSEEKCUR:        jp STARTFSCFH
APIFSEEKEND:        jp STARTFSEFH
APIFREWIND:         jp STARTFRWFH


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

                    ; init LINEBUF to zero
                    ld hl,LINEBUF
                    ld de,LINEBUF+1
                    ld bc, 0x0080
                    ld (hl), 0x00
                    ldir

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
                    

                    ; dummy check to handle 
                    ; return key only
                    ; the '/0' on FILE_CMD
                    ; match the compare
                    ld hl, CMD_RET
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK1

                    ; dispatch
                    jp MAIN_END
                    
MAIN_CHK1:
                    ld hl, CMD_LIST
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK2
                    
                    ; dispatch
                    call STARTLSTF
                    
                    jp MAIN_END

MAIN_CHK2:
                    ld hl, CMD_LOAD
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK3
                    
                    ; dispatch
                    call STARTRFN
                    
                    jp MAIN_END

MAIN_CHK3:
                    ld hl, CMD_REN
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK4
                    
                    ; dispatch
                    call STARTRNFN
                    
                    jp MAIN_END

MAIN_CHK4:
                    ld hl, CMD_COPY
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK5
                    
                    ; dispatch
                    call STARTCPFN
                    
                    jp MAIN_END

MAIN_CHK5:
                    ld hl, CMD_EXIST
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK6
                    
                    ; dispatch
                    call STARTEXFN
                    
                    jp MAIN_END

MAIN_CHK6:
                    ld hl, CMD_MKDIR
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK7
                    
                    ; dispatch
                    call STARTMKDN
                    
                    jp MAIN_END

MAIN_CHK7:
                    ld hl, CMD_RMDIR
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK8
                    
                    ; dispatch
                    call STARTRMDN
                    
                    jp MAIN_END

MAIN_CHK8:
                    ld hl, CMD_CD
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK9
                    
                    ; dispatch
                    call STARTCDDN
                    
                    jp MAIN_END

MAIN_CHK9:
                    ld hl, CMD_CWD
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK10
                    
                    ; dispatch
                    call STARTCWDN
                    
                    jp MAIN_END


MAIN_CHK10:
                    ld hl, CMD_EXIT
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK11
                    
                    ; dispatch
                    jp MAIN_RETURN

MAIN_CHK11:
                    ld hl, CMD_EXIST
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK12
                    
                    ; dispatch
                    call STARTEXFN
                
                    jp MAIN_END

MAIN_CHK12:
                    ld hl, CMD_RESET
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK13
                    
                    ; dispatch
                    call STARTRESET
                                        
                    jp MAIN_END

MAIN_CHK13:
                    ld hl, CMD_SDIFS
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK14
                    
                    ; dispatch
                    call STARTSDIFS
                                        
                    jp MAIN_END

MAIN_CHK14:
                    ld hl, CMD_DEL
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK15

                    ; dispatch
                    call STARTDFN

                    jp MAIN_END

MAIN_CHK15:
                    ld hl, CMD_FOPEN
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK16

                    ; dispatch
                    call STARTFOFN

                    jp MAIN_END

MAIN_CHK16:
                    ld hl, CMD_FCLOSE
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK17

                    ; prepare dispatch
                    ; FILE_NAME to numeric 
                    ; bin at FILE_HDL
                    call FNAME2FHDL

                    ; dispatch
                    call STARTFCFH

                    jp MAIN_END

MAIN_CHK17:
                    ld hl, CMD_FWRITE
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK18

                    ; prepare dispatch
                    ; FILE_NAME to numeric 
                    ; bin at FILE_HDL
                    call FNAME2FHDL

                    ; dispatch
                    call STARTFWFH

                    jp MAIN_END

MAIN_CHK18:
                    ld hl, CMD_FREAD
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK19

                    ; prepare dispatch
                    ; FILE_NAME to numeric 
                    ; bin at FILE_HDL
                    call FNAME2FHDL

                    ; dispatch
                    call STARTFRFH

                    jp MAIN_END

MAIN_CHK19:
                    ld hl, CMD_FGETPOS
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK20

                    ; prepare dispatch
                    ; FILE_NAME to numeric 
                    ; bin at FILE_HDL
                    call FNAME2FHDL

                    ; dispatch
                    call STARTFGPFH

                    jp MAIN_END

MAIN_CHK20:
                    ld hl, CMD_FSEEKSET
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK21

                    ; prepare dispatch
                    ; FILE_NAME to numeric 
                    ; bin at FILE_HDL
                    call FNAME2FHDL

                    ; dispatch
                    call STARTFSSFH

                    jp MAIN_END

MAIN_CHK21:
                    ld hl, CMD_FSEEKCUR
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK22

                    ; prepare dispatch
                    ; FILE_NAME to numeric 
                    ; bin at FILE_HDL
                    call FNAME2FHDL

                    ; dispatch
                    call STARTFSCFH

                    jp MAIN_END

MAIN_CHK22:
                    ld hl, CMD_FSEEKEND
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK23

                    ; prepare dispatch
                    ; FILE_NAME to numeric 
                    ; bin at FILE_HDL
                    call FNAME2FHDL

                    ; dispatch
                    call STARTFSEFH

                    jp MAIN_END

MAIN_CHK23:
                    ld hl, CMD_FREWIND
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK24

                    ; prepare dispatch
                    ; FILE_NAME to numeric 
                    ; bin at FILE_HDL
                    call FNAME2FHDL

                    ; dispatch
                    call STARTFRWFH

                    jp MAIN_END

MAIN_CHK24:
                    ld hl, CMD_SAVE
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_END
                    
                    ; dispatch
                    call STARTWFN

MAIN_END:
                    jp MAIN

MAIN_RETURN:
                    ret

;--------------------------------------------------------
;
; main helper - FILE_NAME to FILE_HLD
;
;--------------------------------------------------------
FNAME2FHDL:
                    ; convert the FILE_NAME field
                    ; to numeric bin at FILE_HDL
                    push hl
                    push de
                    ;
                    ld hl,FILE_NAME
                    call CONVERTTOUPPER

                    call CLI_HEX2TBIN1
                    ld de, FILE_HDL
                    ld (de), a
                    ;
                    call CLI_HEX2TBIN1
                    ld de, FILE_HDL
                    inc de
                    ld (de), a                   
                    ;
                    pop de
                    pop hl

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

                    ; save registers and call compare
                    push hl
                    push de 
                    ld hl, CMD_REN
                    ld de, FILE_CMD
                    call STRCMP
                    pop de                    
                    pop hl                  
                    jr nz, LINE_PARSE1

                    ; dispatch
                    ; 2 file names
                    jr LINE_PARSE2
LINE_PARSE1: 
                    ; save registers and call compare
                    push hl
                    push de 
                    ld hl, CMD_COPY
                    ld de, FILE_CMD
                    call STRCMP
                    pop de                    
                    pop hl
                    jr nz, LINE_PARSE3
LINE_PARSE2:
                     ; dispatch
                    ; 2 file names
                    ; hl pointer to current location on cli 
                    ; set de to the start of the second
                    ; filename string
                    ld de,FILE_NAME1
                    call CLI_GETSTRARG

                    ; we may continue to parse the line
                    ; maybe we need to pass an numeric argument
                    ; jp LINE_PARSE_END

LINE_PARSE3:

                    ; the next argument is an memory address in hex
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
                    ld   hl,FILE_NAME
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

                    ; open file idle status is also acepted
                    ; get status
                    ;in   a,(SDCRS)   
                    ; exit with error message if a != 0
                    ;cp   SDCSFOIDL   
                    ;jr   z,STARTLSTF_OK1 

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
                    cp   SDCSDIRFN
                    jr   z,STARTLSTF_OK2

                    
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

STARTLSTF_OK2:
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
                    ld   hl,FILE_NAME
                    call SENDFNAME   
                    pop  hl
                    pop  bc

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 100
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get status
                    in   a,(SDCRS)   
                    ; is list dir state ?
                    cp   SDCSDIR
                    jr   z, DIRLISTLOOP
                    
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
                    ld   hl,FILE_NAME
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
                    ld   hl,FILE_NAME
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
                    jr   z,STARTRNFN_OK1 
; just info
STARTRNFN_FAIL1:
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

STARTRNFN_OK1:
                    ;
                    ; sdcard status is ok
                    ;

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl


                    ; start rename file
                    ; load cmd code in a, see equs
                    ld   a,SDCMDREN   
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
                    cp   SDCSRENFN1
                    jr   z,STARTRNFN_OK2

                    
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
                    
STARTRNFN_OK2:
                    ;
                    ; ready to send the
                    ; source file name
                    ;
                    ; display ok message
                    ;
                    ;ld   de,STR_SDSTATUS_OK
                    ; load api id
                    ;ld   C,$06
                    ; call api
                    ;rst   $30
                    
                    ;
                    ; send the source file name
                    ;
                    push bc
                    push hl
                    ld   hl,FILE_NAME
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
                    ; is rn file destination state ?
                    cp   SDCSRENFN2
                    jr   z, STARTRNFN_OK3
                    
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

STARTRNFN_OK3:
                    ; ready to send the
                    ; destination file name

                    push bc
                    push hl
                    ld   hl,FILE_NAME1
                    call SENDFNAME   
                    pop  hl
                    pop  bc

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 20
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get status
                    in   a,(SDCRS)   
                    ; is rn file destination state ?
                    cp   SDCSIDL
                    jr   z, STARTRNFN_OK
                    
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

STARTRNFN_OK:                    
                    ;
                    ; display end message
                    ;
                    ld   de,STR_RENOK
                    ; load api id
                    ld   C,$06
                    ; call api
                    rst   $30

                    ret
;--------------------------------------------------------
;
; Copy file on SD
;
;--------------------------------------------------------
STARTCPFN:
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
                    jr   z,STARTCPFN_OK1 
; just info
STARTCPFN_FAIL1:
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

STARTCPFN_OK1:
                    ;
                    ; sdcard status is ok
                    ;

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl


                    ; start rename file
                    ; load cmd code in a, see equs
                    ld   a,SDCMDCOPY   
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
                    ; if status != 40 exit
                    cp   SDCSCPYFN1
                    jr   z,STARTCPFN_OK2

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
                    
STARTCPFN_OK2:

                    ;
                    ; ready to send the
                    ; source file name
                    ;
                    ; display ok message
                    ;
                    ;ld   de,STR_SDSTATUS_OK
                    ; load api id
                    ;ld   C,$06
                    ; call api
                    ;rst   $30
                    
                    ;
                    ; send the source file name
                    ;
                    push bc
                    push hl
                    ld   hl,FILE_NAME
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
                    ; is rn file destination state ?
                    cp   SDCSCPYFN2
                    jr   z, STARTCPFN_OK3

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

STARTCPFN_OK3:
                    ; ready to send the
                    ; destination file name

                    push bc
                    push hl
                    ld   hl,FILE_NAME1
                    call SENDFNAME   
                    pop  hl
                    pop  bc

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 20
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get status
                    in   a,(SDCRS)   
                    ; is rn file destination state ?
                    cp   SDCSIDL
                    jr   z, STARTCPFN_OK
                    
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

STARTCPFN_OK:                    
                    ;
                    ; display end message
                    ;
                    ld   de,STR_COPYOK
                    ; load api id
                    ld   C,$06
                    ; call api
                    rst   $30

                    ret
;--------------------------------------------------------
;
; CD on SD
;
;--------------------------------------------------------
STARTCDDN:
                    ;ld   de,STR_CMD_CD
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
                    jr   z,STARTCDDN_OK1 
; just info
STARTCDDN_FAIL1:
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

STARTCDDN_OK1:
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


                    ; start mkdir
                    ; load cmd code in a, see equs
                    ld   a,SDCMDCD   
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
                    cp   SDCSCHDFN
                    jr   z,STARTCDDN_OK2

                    
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
                    
STARTCDDN_OK2:
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
                    ld   hl,FILE_NAME
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
                    jr   z, STARTCDDN_OK
                    
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
                    
STARTCDDN_OK:                    
                    ;
                    ; display end message
                    ;
                    ld   de,STR_CHDIROK
                    ; load api id
                    ld   C,$06
                    ; call api
                    rst   $30



                        ret

;--------------------------------------------------------
;
; Get current working directory full path name (cwd)
;
;--------------------------------------------------------
STARTCWDN:
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
                    jr   z,STARTCWDN_OK1 
; just info
STARTCWDN_FAIL1:
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

STARTCWDN_OK1:
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
                    ld   a,SDCMDCWD   
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
                    ld  de, 200
                    ld  c, $0a
                    rst $30
                    pop hl
                    
CWDNLOOP:
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
                    cp   SDCSCWD                     
  
                    ; directory listed
                    jr  nz, CWDNEND_OK
                    
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
                    
                    jr CWDNLOOP
                      
                    
CWDNEND_OK:
                    ;
                    ; directory was listed
                    ;
                    ; output nl & cr
                    ld a, '\n'
                    call OUTCHAR
                    ld a, '\r'
                    call OUTCHAR  

                    ;
                    ; display end message
                    ;
                    ld   de,STR_CWDOK
                    ; load api id
                    ld   C,$06
                    ; call api
                    rst   $30
                    
                    ; return
                    ret


;--------------------------------------------------------
;
; Make directory on SD (mkdir)
;
;--------------------------------------------------------
STARTMKDN:
                    ;ld   de,STR_CMD_MKDIR
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
                    jr   z,STARTMKDN_OK1 
; just info
STARTMKDN_FAIL1:
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

STARTMKDN_OK1:
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


                    ; start mkdir
                    ; load cmd code in a, see equs
                    ld   a,SDCMDMKDIR   
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
                    cp   SDCSMKDFN
                    jr   z,STARTMKDN_OK2

                    
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
                    
STARTMKDN_OK2:
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
                    ld   hl,FILE_NAME
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
                    jr   z, STARTMKDN_OK
                    
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
                    
STARTMKDN_OK:                    
                    ;
                    ; display end message
                    ;
                    ld   de,STR_MKDIROK
                    ; load api id
                    ld   C,$06
                    ; call api
                    rst   $30


                    ret

;--------------------------------------------------------
;
; Remove directory on SD (mkdir)
;
;--------------------------------------------------------
STARTRMDN:
                    ;ld   de,STR_CMD_RMDIR
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
                    jr   z,STARTRMDN_OK1 
; just info
STARTRMDN_FAIL1:
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

STARTRMDN_OK1:
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


                    ; start mkdir
                    ; load cmd code in a, see equs
                    ld   a,SDCMDRMDIR   
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
                    cp   SDCSRMDFN
                    jr   z,STARTRMDN_OK2

                    
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
                    
STARTRMDN_OK2:
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
                    ld   hl,FILE_NAME
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
                    jr   z, STARTRMDN_OK
                    
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
                    
STARTRMDN_OK:                    
                    ;
                    ; display end message
                    ;
                    ld   de,STR_RMDIROK
                    ; load api id
                    ld   C,$06
                    ; call api
                    rst   $30

                    ret

;--------------------------------------------------------
;
; Reset the SD card interface, status > 0x00 (reset)
;
;--------------------------------------------------------
STARTRESET:
                    
                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; send reset command
                    ; load cmd code in a, see equs
                    ld   a,SDCMDRESET   
                    out   (SDCWC),a

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
                    cp   SDCSIDL
                    jr   z,STARTRESET_OK

                    
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

STARTRESET_OK:                    
                    ;
                    ; display end message
                    ;
                    ld   de,STR_RESETOK
                    ; load api id
                    ld   C,$06
                    ; call api
                    rst   $30

                    ret

;--------------------------------------------------------
;
; Getet the SD card interface status (sdifs)
;
;--------------------------------------------------------
STARTSDIFS: 
                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; get status
                    in   a,(SDCRS)   

                    ; convert to hex
                    call NUM2HEX;

                    ; display hex
                    ld a, d
                    call OUTCHAR 
                    ld a, e
                    call OUTCHAR 

                    ld a, '\n'
                    call OUTCHAR 
                    ld a, '\r'
                    call OUTCHAR          
               
                    ;
                    ; display end message
                    ;
                    ld   de,STR_SDIFSOK
                    ; load api id
                    ld   C,$06
                    ; call api
                    rst   $30

                    ret

;--------------------------------------------------------
;
; Check if file exists
;
;--------------------------------------------------------
STARTEXFN:
                    ;ld   de,STR_CMD_EXIST
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
                    jr   z,STARTEXFN_OK1 
; just info
STARTEXFN_FAIL1:
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

STARTEXFN_OK1:
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


                    ; start mkdir
                    ; load cmd code in a, see equs
                    ld   a,SDCMDEXIST   
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
                    cp   SDCSEXISFN
                    jr   z,STARTEXFN_OK2
                    
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

STARTEXFN_OK2:
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
                    ld   hl,FILE_NAME
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
                    cp   SDCSEXIST
                    jr   z, STARTEXFN_OK3
                    
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

STARTEXFN_OK3:
                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; get data
                    in   a,(SDCRD)

                    ; convert to hex
                    call NUM2HEX;

                    ; display hex
                    ld a, d
                    call OUTCHAR 
                    ld a, e
                    call OUTCHAR 

                    ld a, '\n'
                    call OUTCHAR 
                    ld a, '\r'
                    call OUTCHAR 

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; get status
                    in   a,(SDCRS)   
                    ; is rfile state ?
                    cp   SDCSIDL
                    jr   z, STARTEXFN_OK

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

STARTEXFN_OK:                    
                    ;
                    ; display end message
                    ;
                    ld   de,STR_EXISTOK
                    ; load api id
                    ld   C,$06
                    ; call api
                    rst   $30

                        ret
;--------------------------------------------------------
;
; File open on SD, with name & mode - int ofhld = fopen (char *fn, int32 *mode)
;
;--------------------------------------------------------
STARTFOFN:
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
                    jr   z,STARTFOFN_OK1 

                    ; open file idle status is also acepted
                    ; get status
                    ;in   a,(SDCRS)   
                    ; exit with error message if a != 0
                    ;cp   SDCSFOIDL   
                    ;jr   z,STARTFOFN_OK1 

; just info
STARTFOFN_FAIL1:
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

STARTFOFN_OK1:
                    ;
                    ; sdcard status is ok
                    ;

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl


                    ; start file open
                    ; load cmd code in a, see equs
                    ld   a,SDCMDFOPEN   
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
                    ; if status != 160 exit
                    cp   SDCSFOFN
                    jr   z,STARTFOFN_OK2

                    
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
                    
STARTFOFN_OK2:
                    ;
                    ; ready to send the
                    ; source file name
                    ;
                    ; display ok message
                    ;
                    ;ld   de,STR_SDSTATUS_OK
                    ; load api id
                    ;ld   C,$06
                    ; call api
                    ;rst   $30
                    
                    ;
                    ; send the source file name
                    ;
                    push bc
                    push hl
                    ld   hl,FILE_NAME
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
                    ; is the send mode state?
                    cp   SDCSFOFM
                    jr   z, STARTFOFN_OK3
                    
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

STARTFOFN_OK3:
                    ; ready to send the
                    ; mode to open file

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; send HB
                    push hl
                    push af
                    ld   hl,FILE_START
                    ld   a, (hl)

                    ;push af

                    ; convert to hex
                    ;call NUM2HEX;

                    ; display hex
                    ;ld a, d
                    ;call OUTCHAR 
                    ;ld a, e
                    ;call OUTCHAR 

                    ;ld a, '\n'
                    ;call OUTCHAR 
                    ;ld a, '\r'
                    ;call OUTCHAR

                    ;pop af


                    out (SDCWD),a

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; send LB
                    inc  hl
                    ld   a, (hl)

                    out (SDCWD),a
                    pop  af
                    pop  hl

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl
                   
                    ; get status
                    in   a,(SDCRS)   
                    ; is the send mode state?
                    cp   SDCSCFOGH
                    jr   z, STARTFOFN_OK4  

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

STARTFOFN_OK4:
                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get data
                    in   a,(SDCRD)   
                    ; is the send mode state?

                    ; register a have the file
                    ; handler. just show it
                    ; later may need to save in 
                    ; a memory address for
                    ; program api
                    
                    ;push de
                    push af

                    ; convert to hex
                    call NUM2HEX;

                    ; display hex
                    ld a, d
                    call OUTCHAR 
                    ld a, e
                    call OUTCHAR 

                    ld a, '\n'
                    call OUTCHAR 
                    ld a, '\r'
                    call OUTCHAR

                    pop af
                    ;pop de

                    ; get status
                    in   a,(SDCRS)   
                    ; is rn file destination state ?
                    cp   SDCSIDL
                    jr   z, STARTFOFN_OK
                    
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

STARTFOFN_OK:                    
                    ;
                    ; display end message
                    ;
                    ld   de,STR_OK
                    ; load api id
                    ld   C,$06
                    ; call api
                    rst   $30

                    ret

;--------------------------------------------------------
;
; File close on SD - fclose (int *ofhld)
;
;--------------------------------------------------------
STARTFCFH:
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
                    jr   z,STARTFCFH_OK1 

                    ; open file idle status is also acepted
                    ; get status
                    ;in   a,(SDCRS)   
                    ; exit with error message if a != 0
                    ;cp   SDCSFOIDL   
                    ;jr   z,STARTFOFN_OK1

; just info
STARTFCFH_FAIL1:
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

STARTFCFH_OK1:
                    ;
                    ; sdcard status is ok
                    ;

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; start close file
                    ; load cmd code in a, see equs
                    ld   a,SDCMDFCLOSE   
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
                    ; if status != 160 exit
                    cp   SDCSCFHDL
                    jr   z,STARTFCFH_OK2

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

STARTFCFH_OK2:
                    ; ready to send the
                    ; hdl id of file to close

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; send HB
                    push hl
                    push af
                    ld   hl,FILE_HDL
                    ld   a, (hl)

                    ;push af

                    ; convert to hex
                    ;call NUM2HEX;

                    ; display hex
                    ;ld a, d
                    ;call OUTCHAR 
                    ;ld a, e
                    ;call OUTCHAR 

                    ;ld a, '\n'
                    ;call OUTCHAR 
                    ;ld a, '\r'
                    ;call OUTCHAR

                    ;pop af

                    out (SDCWD),a

                    pop  af
                    pop  hl

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl
                   
                    ; get status
                    in   a,(SDCRS)   
                    ; is the send mode state?
                    cp   SDCSIDL
                    jr   z, STARTFCFH_OK3  

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

STARTFCFH_OK3:
                    ;
                    ; display end message
                    ;
                    ld   de,STR_OK
                    ; load api id
                    ld   C,$06
                    ; call api
                    rst   $30

                    ret
;--------------------------------------------------------
;
; File write one byte - fwrite (int *ofhld, int b)
;
;--------------------------------------------------------
STARTFWFH:
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
                    jr   z,STARTFWFH_OK1 

                    ; open file idle status is also acepted
                    ; get status
                    ;in   a,(SDCRS)   
                    ; exit with error message if a != 0
                    ;cp   SDCSFOIDL   
                    ;jr   z,STARTFOFN_OK1

; just info
STARTFWFH_FAIL1:
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

STARTFWFH_OK1:
                    ;
                    ; sdcard status is ok
                    ;

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; start close file
                    ; load cmd code in a, see equs
                    ld   a,SDCMDFWRITE   
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
                    ; if status != 192 exit
                    cp   SDCSFWHDL
                    jr   z,STARTFWFH_OK2

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

STARTFWFH_OK2:
                    ; ready to send the
                    ; hdl id of file to close

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; send HB
                    push hl
                    push af
                    ld   hl,FILE_HDL
                    ld   a, (hl)

                    ;push af

                    ; convert to hex
                    ;call NUM2HEX;

                    ; display hex
                    ;ld a, d
                    ;call OUTCHAR 
                    ;ld a, e
                    ;call OUTCHAR 

                    ;ld a, '\n'
                    ;call OUTCHAR 
                    ;ld a, '\r'
                    ;call OUTCHAR

                    ;pop af

                    out (SDCWD),a

                    pop  af
                    pop  hl

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl
                   
                    ; get status
                    in   a,(SDCRS)   
                    ; is the send mode state?
                    cp   SDCSFWRITE
                    jr   z, STARTFWFH_OK3  

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

STARTFWFH_OK3:
                    ; ready to send the
                    ; byte (write byte)

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; send HB
                    push hl
                    push af
                    ld   hl,FILE_START
                    ld   a, (hl)

                    ;push af

                    ; convert to hex
                    ;call NUM2HEX;

                    ; display hex
                    ;ld a, d
                    ;call OUTCHAR 
                    ;ld a, e
                    ;call OUTCHAR 

                    ;ld a, '\n'
                    ;call OUTCHAR 
                    ;ld a, '\r'
                    ;call OUTCHAR

                    ;pop af

                    out (SDCWD),a

                    pop  af
                    pop  hl

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl
                   
                    ; get status
                    in   a,(SDCRS)   
                    ; is the send operation result state?
                    cp   SDCSFWSTAT
                    jr   z, STARTFWFH_OK4  

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

STARTFWFH_OK4:
                    ; read operation result

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get data
                    in   a,(SDCRD)   
                    
                    ;
                    ; show command result
                    ;
                    ;push de
                    push af

                    ; convert to hex
                    call NUM2HEX;

                    ; display hex
                    ld a, d
                    call OUTCHAR 
                    ld a, e
                    call OUTCHAR 

                    ld a, '\n'
                    call OUTCHAR 
                    ld a, '\r'
                    call OUTCHAR

                    pop af
                    ;pop de

                    ; get status
                    in   a,(SDCRS)   
                    ; is rn file destination state ?
                    cp   SDCSIDL
                    jr   z, STARTFWFH_OK
                    
                    ; display error message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    
                    ; return
                    ret

STARTFWFH_OK:
                    ; display end message
                    ; using scm api
                    ld   de,STR_OK
                    ld   C,$06
                    rst   $30

                    ret

;--------------------------------------------------------
;
; File read one byte - fread (int *ofhld)
;
;--------------------------------------------------------
STARTFRFH:
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
                    jr   z,STARTFRFH_OK1 

; just info
STARTFRFH_FAIL1:
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

STARTFRFH_OK1:
                    ;
                    ; sdcard status is ok
                    ;

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; start read byte from file
                    ; load cmd code in a, see equs
                    ld   a,SDCMDFREAD   
                    out   (SDCWC),a
                    
                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl
                    
                    ; get status
                    in   a,(SDCRS)   
                    ; if status != 192 exit
                    cp   SDCSFRHDL
                    jr   z,STARTFRFH_OK2

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

STARTFRFH_OK2:
                    ; ready to send the
                    ; hdl id of file to close

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; send HB
                    push hl
                    push af
                    ld   hl,FILE_HDL
                    ld   a, (hl)

                    ;push af

                    ; convert to hex
                    ;call NUM2HEX;

                    ; display hex
                    ;ld a, d
                    ;call OUTCHAR 
                    ;ld a, e
                    ;call OUTCHAR 

                    ;ld a, '\n'
                    ;call OUTCHAR 
                    ;ld a, '\r'
                    ;call OUTCHAR

                    ;pop af

                    out (SDCWD),a

                    pop  af
                    pop  hl

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl
                   
                    ; get status
                    in   a,(SDCRS)   
                    ; is the send mode state?
                    cp   SDCSFREAD
                    jr   z, STARTFRFH_OK3  

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

STARTFRFH_OK3:
                    ; read the byte from file

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get data
                    in   a,(SDCRD)   
                    
                    ;
                    ; show byte read
                    ;
                    ;push de
                    push af

                    ; convert to hex
                    call NUM2HEX;

                    ; display hex
                    ld a, d
                    call OUTCHAR 
                    ld a, e
                    call OUTCHAR 

                    ld a, '\n'
                    call OUTCHAR 
                    ld a, '\r'
                    call OUTCHAR

                    pop af
                    ;pop de

                    ; get status
                    in   a,(SDCRS)   
                    ; is rn file destination state ?
                    cp   SDCSFRSTAT
                    jr   z, STARTFRFH_OK4
                    
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


STARTFRFH_OK4:
                    ; read operation result

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get data
                    in   a,(SDCRD)

                    ;
                    ; show command result
                    ;
                    
                    ;push de
                    push af

                    ; convert to hex
                    call NUM2HEX;

                    ; display hex
                    ld a, d
                    call OUTCHAR 
                    ld a, e
                    call OUTCHAR 

                    ld a, '\n'
                    call OUTCHAR 
                    ld a, '\r'
                    call OUTCHAR

                    pop af
                    ;pop de

                    ; get status
                    in   a,(SDCRS)   
                    ; is in idle state ?
                    cp   SDCSIDL
                    jp   z, STARTFRFH_OK
                    
                    ; display error message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    
                    ; return
                    ret

STARTFRFH_OK:
                    ; display end message
                    ; using scm api
                    ld   de,STR_OK
                    ld   C,$06
                    rst   $30

                    ret

;--------------------------------------------------------
;
; Get file current position - fcurpos (int *ofhld)
;
;--------------------------------------------------------
STARTFGPFH:
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
                    jr   z,STARTFGPFH_OK1 

; just info
STARTFGPFH_FAIL1:
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

STARTFGPFH_OK1:
                    ;
                    ; sdcard status is ok
                    ;

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; start get pos on file
                    ; load cmd code in a, see equs
                    ld   a,SDCMDFGPOS   
                    out   (SDCWC),a
                    
                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl
                    
                    ; get status
                    in   a,(SDCRS)   
                    ; if status != 192 exit
                    cp   SDCSFGPHDL
                    jr   z,STARTFGPFH_OK2

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

STARTFGPFH_OK2:
                    ; ready to send the
                    ; hdl id of file to get pos

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; send HB
                    push hl
                    push af
                    ld   hl,FILE_HDL
                    ld   a, (hl)

                    ;push af

                    ; convert to hex
                    ;call NUM2HEX;

                    ; display hex
                    ;ld a, d
                    ;call OUTCHAR 
                    ;ld a, e
                    ;call OUTCHAR 

                    ;ld a, '\n'
                    ;call OUTCHAR 
                    ;ld a, '\r'
                    ;call OUTCHAR

                    ;pop af

                    out (SDCWD),a

                    pop  af
                    pop  hl

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl
                   
                    ; get status
                    in   a,(SDCRS)   
                    ; is the send mode state?
                    cp   SDCSFGPOS
                    jr   z, STARTFGPFH_OK3  

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

STARTFGPFH_OK3:
                    ; read pos byte from file

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get data
                    in   a,(SDCRD)   
                    
                    ;
                    ; show byte read
                    ;
                    ;push de
                    push af

                    ; convert to hex
                    call NUM2HEX;

                    ; display hex
                    ld a, d
                    call OUTCHAR 
                    ld a, e
                    call OUTCHAR 

                    ld a, '\n'
                    call OUTCHAR 
                    ld a, '\r'
                    call OUTCHAR

                    pop af
                    ;pop de

                    ; get status
                    in   a,(SDCRS)   
                    ; are bytes available ?
                    cp   SDCSFGPOS
                    jr   z, STARTFGPFH_OK3
                    
                    ;
                    ; no more bytes for
                    ; position in file
                    ;

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get status
                    in   a,(SDCRS)   
                    ; is in idle state ?
                    cp   SDCSIDL
                    jp   z, STARTFGPFH_OK
                    
                    ; display error message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    
                    ; return
                    ret


STARTFGPFH_OK:
                    ; display end message
                    ; using scm api
                    ld   de,STR_OK
                    ld   C,$06
                    rst   $30

                    ret

;--------------------------------------------------------
;
; File position set - seekset (int *ofhld, int32 p)
;
;--------------------------------------------------------
STARTFSSFH:
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
                    jr   z,STARTFSSFH_OK1 

                    ; open file idle status is also acepted
                    ; get status
                    ;in   a,(SDCRS)   
                    ; exit with error message if a != 0
                    ;cp   SDCSFOIDL   
                    ;jr   z,STARTFOFN_OK1

; just info
STARTFSSFH_FAIL1:
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

STARTFSSFH_OK1:
                    ;
                    ; sdcard status is ok
                    ;

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; start close file
                    ; load cmd code in a, see equs
                    ld   a,SDCMDFSEKSET   
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
                    ; if status != 216 exit
                    cp   SDCSFSSHDL
                    jr   z,STARTFSSFH_OK2

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

STARTFSSFH_OK2:
                    ; ready to send the
                    ; hdl id of file to close

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; send HB
                    push hl
                    push af
                    ld   hl,FILE_HDL
                    ld   a, (hl)

                    ;push af

                    ; convert to hex
                    ;call NUM2HEX;

                    ; display hex
                    ;ld a, d
                    ;call OUTCHAR 
                    ;ld a, e
                    ;call OUTCHAR 

                    ;ld a, '\n'
                    ;call OUTCHAR 
                    ;ld a, '\r'
                    ;call OUTCHAR

                    ;pop af

                    out (SDCWD),a

                    pop  af
                    pop  hl

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl
                   
                    ; get status
                    in   a,(SDCRS)   
                    ; is the send mode state?
                    cp   SDCSSEKSET
                    jr   z, STARTFSSFH_OK3  

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

STARTFSSFH_OK3:
                    ; ready to send the four bytes (32bits)
                    ; to set position on file

                    ; we use:
                    ; - FILE_START 16bits
                    ; - FILE_LEN 16bits

                    ;
                    ; first the FILE_START
                    ;

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; send HB
                    push hl
                    push af
                    ld   hl,FILE_START
                    ld   a, (hl)

                    ;push af

                    ; convert to hex
                    ;call NUM2HEX;

                    ; display hex
                    ;ld a, d
                    ;call OUTCHAR 
                    ;ld a, e
                    ;call OUTCHAR 

                    ;ld a, '\n'
                    ;call OUTCHAR 
                    ;ld a, '\r'
                    ;call OUTCHAR

                    ;pop af


                    out (SDCWD),a

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; send LB
                    inc  hl
                    ld   a, (hl)

                    out (SDCWD),a
                    pop  af
                    pop  hl

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ;
                    ; now the FILE_LEN
                    ;

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; send HB
                    push hl
                    push af
                    ld   hl,FILE_LEN
                    ld   a, (hl)

                    ;push af

                    ; convert to hex
                    ;call NUM2HEX;

                    ; display hex
                    ;ld a, d
                    ;call OUTCHAR 
                    ;ld a, e
                    ;call OUTCHAR 

                    ;ld a, '\n'
                    ;call OUTCHAR 
                    ;ld a, '\r'
                    ;call OUTCHAR

                    ;pop af


                    out (SDCWD),a

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; send LB
                    inc  hl
                    ld   a, (hl)

                    out (SDCWD),a
                    pop  af
                    pop  hl

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 10
                    ld   c, $0a
                    rst  $30
                    pop  hl

                   
                    ; get status
                    in   a,(SDCRS)   
                    ; is the send operation result state?
                    cp   SDCSFSSSTAT
                    jr   z, STARTFSSFH_OK4  

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

STARTFSSFH_OK4:
                    ; read operation result

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get data
                    in   a,(SDCRD)   
                    
                    ;
                    ; show command result
                    ;
                    ;push de
                    push af

                    ; convert to hex
                    call NUM2HEX;

                    ; display hex
                    ld a, d
                    call OUTCHAR 
                    ld a, e
                    call OUTCHAR 

                    ld a, '\n'
                    call OUTCHAR 
                    ld a, '\r'
                    call OUTCHAR

                    pop af
                    ;pop de

                    ; get status
                    in   a,(SDCRS)   
                    ; is rn file destination state ?
                    cp   SDCSIDL
                    jr   z, STARTFSSFH_OK
                    
                    ; display error message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    
                    ; return
                    ret

STARTFSSFH_OK:
                    ; display end message
                    ; using scm api
                    ld   de,STR_OK
                    ld   C,$06
                    rst   $30

                    ret

;--------------------------------------------------------
;
; File position set - seekcur (int *ofhld, int32 p)
;
;--------------------------------------------------------
STARTFSCFH:
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
                    jr   z,STARTFSCFH_OK1 

; just info
STARTFSCFH_FAIL1:
                    ; display error message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30

                    ret

STARTFSCFH_OK1:
                    ;
                    ; sdcard status is ok
                    ;

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; start close file
                    ; load cmd code in a, see equs
                    ld   a,SDCMDFSEKCUR   
                    out   (SDCWC),a
                    
                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl
                    
                    ; get status
                    in   a,(SDCRS)   
                    ; if status != 216 exit
                    cp   SDCSFSCHDL
                    jr   z,STARTFSCFH_OK2

                    ; display error message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                   
                    ret 

STARTFSCFH_OK2:
                    ; ready to send the
                    ; hdl id of file to close

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; send HB
                    push hl
                    push af
                    ld   hl,FILE_HDL
                    ld   a, (hl)

                    ;push af

                    ; convert to hex
                    ;call NUM2HEX;

                    ; display hex
                    ;ld a, d
                    ;call OUTCHAR 
                    ;ld a, e
                    ;call OUTCHAR 

                    ;ld a, '\n'
                    ;call OUTCHAR 
                    ;ld a, '\r'
                    ;call OUTCHAR

                    ;pop af

                    out (SDCWD),a

                    pop  af
                    pop  hl

                    ; wait a ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl
                   
                    ; get status
                    in   a,(SDCRS)   
                    ; is the send mode state?
                    cp   SDCSSEKCUR
                    jr   z, STARTFSCFH_OK3  

                    ; display error message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30

                    ret                  

STARTFSCFH_OK3:
                    ; ready to send the four bytes (32bits)
                    ; to set position on file

                    ; we use:
                    ; - FILE_START 16bits
                    ; - FILE_LEN 16bits

                    ;
                    ; first the FILE_START
                    ;

                    ; wait a ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; send HB
                    push hl
                    push af
                    ld   hl,FILE_START
                    ld   a, (hl)

                    ;push af

                    ; convert to hex
                    ;call NUM2HEX;

                    ; display hex
                    ;ld a, d
                    ;call OUTCHAR 
                    ;ld a, e
                    ;call OUTCHAR 

                    ;ld a, '\n'
                    ;call OUTCHAR 
                    ;ld a, '\r'
                    ;call OUTCHAR

                    ;pop af


                    out (SDCWD),a

                    ; wait a ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; send LB
                    inc  hl
                    ld   a, (hl)

                    out (SDCWD),a
                    pop  af
                    pop  hl

                    ; wait a ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ;
                    ; now the FILE_LEN
                    ;

                    ; wait a ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; send HB
                    push hl
                    push af
                    ld   hl,FILE_LEN
                    ld   a, (hl)

                    ;push af

                    ; convert to hex
                    ;call NUM2HEX;

                    ; display hex
                    ;ld a, d
                    ;call OUTCHAR 
                    ;ld a, e
                    ;call OUTCHAR 

                    ;ld a, '\n'
                    ;call OUTCHAR 
                    ;ld a, '\r'
                    ;call OUTCHAR

                    ;pop af


                    out (SDCWD),a

                    ; wait a ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; send LB
                    inc  hl
                    ld   a, (hl)

                    out (SDCWD),a
                    pop  af
                    pop  hl

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 10
                    ld   c, $0a
                    rst  $30
                    pop  hl

                   
                    ; get status
                    in   a,(SDCRS)   
                    ; is the send operation result state?
                    cp   SDCSFSCSTAT
                    jr   z, STARTFSCFH_OK4  

                    ; display error message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30

                    ret                  

STARTFSCFH_OK4:
                    ; read operation result

                    ; wait a ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get data
                    in   a,(SDCRD)   
                    
                    ;
                    ; show command result
                    ;
                    ;push de
                    push af

                    ; convert to hex
                    call NUM2HEX;

                    ; display hex
                    ld a, d
                    call OUTCHAR 
                    ld a, e
                    call OUTCHAR 

                    ld a, '\n'
                    call OUTCHAR 
                    ld a, '\r'
                    call OUTCHAR

                    pop af
                    ;pop de

                    ; get status
                    in   a,(SDCRS)   
                    ; is rn file destination state ?
                    cp   SDCSIDL
                    jr   z, STARTFSCFH_OK
                    
                    ; display error message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    
                    ; return
                    ret

STARTFSCFH_OK:
                    ; display end message
                    ; using scm api
                    ld   de,STR_OK
                    ld   C,$06
                    rst   $30

                    ret

;--------------------------------------------------------
;
; File position set - seekend (int *ofhld, int32 p)
;
;--------------------------------------------------------
STARTFSEFH:
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
                    jr   z,STARTFSEFH_OK1 

                    ; open file idle status is also acepted
                    ; get status
                    ;in   a,(SDCRS)   
                    ; exit with error message if a != 0
                    ;cp   SDCSFOIDL   
                    ;jr   z,STARTFOFN_OK1

; just info
STARTFSEFH_FAIL1:
                    ; display error message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30

                    ret

STARTFSEFH_OK1:
                    ;
                    ; sdcard status is ok
                    ;

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; start close file
                    ; load cmd code in a, see equs
                    ld   a,SDCMDFSEKEND   
                    out   (SDCWC),a

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl
                    
                    ; get status
                    in   a,(SDCRS)   
                    ; if status != 216 exit
                    cp   SDCSFSEHDL
                    jr   z,STARTFSEFH_OK2

                    ; display error message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30

                    ; return                    
                    ret 

STARTFSEFH_OK2:
                    ; ready to send the
                    ; hdl id of file to close

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; send HB
                    push hl
                    push af
                    ld   hl,FILE_HDL
                    ld   a, (hl)

                    ;push af

                    ; convert to hex
                    ;call NUM2HEX;

                    ; display hex
                    ;ld a, d
                    ;call OUTCHAR 
                    ;ld a, e
                    ;call OUTCHAR 

                    ;ld a, '\n'
                    ;call OUTCHAR 
                    ;ld a, '\r'
                    ;call OUTCHAR

                    ;pop af

                    out (SDCWD),a

                    pop  af
                    pop  hl

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl
                   
                    ; get status
                    in   a,(SDCRS)   
                    ; is the send mode state?
                    cp   SDCSSEKEND
                    jr   z, STARTFSEFH_OK3  

                    ; display error message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30

                    ; return
                    ret                  

STARTFSEFH_OK3:
                    ; ready to send the four bytes (32bits)
                    ; to set position on file

                    ; we use:
                    ; - FILE_START 16bits
                    ; - FILE_LEN 16bits

                    ;
                    ; first the FILE_START
                    ;

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; send HB
                    push hl
                    push af
                    ld   hl,FILE_START
                    ld   a, (hl)

                    ;push af

                    ; convert to hex
                    ;call NUM2HEX;

                    ; display hex
                    ;ld a, d
                    ;call OUTCHAR 
                    ;ld a, e
                    ;call OUTCHAR 

                    ;ld a, '\n'
                    ;call OUTCHAR 
                    ;ld a, '\r'
                    ;call OUTCHAR

                    ;pop af


                    out (SDCWD),a

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; send LB
                    inc  hl
                    ld   a, (hl)

                    out (SDCWD),a
                    pop  af
                    pop  hl

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ;
                    ; now the FILE_LEN
                    ;

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; send HB
                    push hl
                    push af
                    ld   hl,FILE_LEN
                    ld   a, (hl)

                    ;push af

                    ; convert to hex
                    ;call NUM2HEX;

                    ; display hex
                    ;ld a, d
                    ;call OUTCHAR 
                    ;ld a, e
                    ;call OUTCHAR 

                    ;ld a, '\n'
                    ;call OUTCHAR 
                    ;ld a, '\r'
                    ;call OUTCHAR

                    ;pop af


                    out (SDCWD),a

                    ; wait a ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; send LB
                    inc  hl
                    ld   a, (hl)

                    out (SDCWD),a
                    pop  af
                    pop  hl

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 10
                    ld   c, $0a
                    rst  $30
                    pop  hl

                   
                    ; get status
                    in   a,(SDCRS)   
                    ; is the send operation result state?
                    cp   SDCSFSESTAT
                    jr   z, STARTFSEFH_OK4  

                    ; display error message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30

                    ; return
                    ret                  

STARTFSEFH_OK4:
                    ; read operation result

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get data
                    in   a,(SDCRD)   
                    
                    ;
                    ; show command result
                    ;
                    ;push de
                    push af

                    ; convert to hex
                    call NUM2HEX;

                    ; display hex
                    ld a, d
                    call OUTCHAR 
                    ld a, e
                    call OUTCHAR 

                    ld a, '\n'
                    call OUTCHAR 
                    ld a, '\r'
                    call OUTCHAR

                    pop af
                    ;pop de

                    ; get status
                    in   a,(SDCRS)   
                    ; is rn file destination state ?
                    cp   SDCSIDL
                    jr   z, STARTFSEFH_OK
                    
                    ; display error message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    
                    ; return
                    ret

STARTFSEFH_OK:
                    ; display end message
                    ; using scm api
                    ld   de,STR_OK
                    ld   C,$06
                    rst   $30

                    ret

;--------------------------------------------------------
;
; File position set - rewind (int *ofhld)
;
;--------------------------------------------------------
STARTFRWFH:
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
                    jr   z,STARTFRWFH_OK1 

; just info
STARTFRWFH_FAIL1:
                    ; display error message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30

                    ret

STARTFRWFH_OK1:
                    ;
                    ; sdcard status is ok
                    ;

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; start close file
                    ; load cmd code in a, see equs
                    ld   a,SDCMDFREWIND   
                    out   (SDCWC),a

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl
                    
                    ; get status
                    in   a,(SDCRS)   
                    ; if status != 216 exit
                    cp   SDCSFRWDHDL
                    jr   z,STARTFRWFH_OK2

                    ; display error message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30

                    ; return                    
                    ret 

STARTFRWFH_OK2:
                    ; ready to send the
                    ; hdl id of file to close

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; send HB
                    push hl
                    push af
                    ld   hl,FILE_HDL
                    ld   a, (hl)

                    ;push af

                    ; convert to hex
                    ;call NUM2HEX;

                    ; display hex
                    ;ld a, d
                    ;call OUTCHAR 
                    ;ld a, e
                    ;call OUTCHAR 

                    ;ld a, '\n'
                    ;call OUTCHAR 
                    ;ld a, '\r'
                    ;call OUTCHAR

                    ;pop af

                    out (SDCWD),a

                    pop  af
                    pop  hl

                    ; wait 10 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl
                   
                    ; get status
                    in   a,(SDCRS)   
                    ; is the send mode state?
                    cp   SDCSIDL
                    jr   z, STARTFRWFH_OK 

                    ; display error message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30

                    ret                  

STARTFRWFH_OK:
                    ; display end message
                    ; using scm api
                    ld   de,STR_OK
                    ld   C,$06
                    rst   $30

                    ret

;--------------------------------------------------------
; 
; send file name or directory name
;
;--------------------------------------------------------

SENDFNAME:      
                    ; point hl to start of string
                    ; caller must pass the 
                    ; string address in hl
                    ;ld   hl,FILE_NAME   
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
            ; input: hl address string1
            ;        de address string2
            ; return: z if equal
            ; afects: a, b
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

NUM2HEX:
                    ; input on a
                    ; result on de
                    push bc
                    ld c, a   ; a = number to convert
                    call NUM2HEX1
                    ld d, a
                    ld a, c
                    call NUM2HEX2
                    ld e, a
                    pop bc
                    ret  ; return with hex number in de

NUM2HEX1:
                    rra
                    rra
                    rra
                    rra
NUM2HEX2:        
                    or 0xF0
                    daa
                    add a, 0xA0
                    adc a, 0x40 ; Ascii hex at this point (0 to F)   
                    ret     

;--------------------------------------------


OUTCHAR:      
                    ; print char on
                    ; register A
                    push    bc
                    push    de
                    push    hl
                    ld      c,$02   
                    rst     $30   
                    pop     hl
                    pop     de
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
STR_RENOK:          DB      "File renamed\n\r",0
STR_COPYOK:          DB      "File copied\n\r",0
STR_EXISTOK:          DB      "File verified\n\r",0
STR_MKDIROK:          DB      "Directory created\n\r",0
STR_RMDIROK:          DB      "Directory removed\n\r",0
STR_CHDIROK:          DB      "Directory changed\n\r",0
STR_CWDOK:            DB      "Current directory\n\r",0
STR_RESETOK:          DB      "SD card iff reset\n\r",0
STR_SDIFSOK:          DB      "SD card iff status\n\r",0

;
; command list
; 
CMD_RET:             DB      "RET",0 ; not real command, only handle return key only
CMD_LOAD:            DB      "LOAD",0
CMD_SAVE:            DB      "SAVE",0
CMD_DEL:             DB      "DEL",0
CMD_LIST:            DB      "LIST",0
CMD_REN:             DB      "REN",0
CMD_COPY:            DB      "COPY",0
CMD_EXIST:            DB      "EXIST",0
CMD_MKDIR:            DB      "MKDIR",0
CMD_RMDIR:            DB      "RMDIR",0
CMD_CD:               DB      "CD",0
CMD_CWD:              DB      "CWD",0
CMD_EXIT:             DB      "EXIT",0
CMD_RESET:            DB      "RESET",0
CMD_SDIFS:            DB      "SDIFS",0
CMD_FOPEN:            DB      "FOPEN",0
CMD_FCLOSE:           DB      "FCLOSE",0
CMD_FWRITE:           DB      "FWRITE",0
CMD_FREAD:            DB      "FREAD",0
CMD_FGETPOS:          DB      "FGETPOS",0
CMD_FSEEKSET:         DB      "FSEEKSET",0
CMD_FSEEKCUR:         DB      "FSEEKCUR",0
CMD_FSEEKEND:         DB      "FSEEKEND",0
CMD_FREWIND:          DB      "FREWIND",0
CMD_FPEEK:            DB      "FPEEK",0

;
; RAM zone - variables
;

;                    ORG    $83E0
;                    ORG    $FAE0
                    ORG    $FA00                    
RAMDATA:
NUM_BYTES:          DS $02 ; 2 bytes
FILE_START:         DS $02 ; 2 bytes
FILE_LEN:           DS $02 ; 2 bytes
FILE_CMD:           DS $10 ; 16 bytes
FILE_NAME:          DS $21 ; 33 bytes
FILE_NAME1:         DS $21 ; 33 bytes
FILE_OMODE:         DS $04 ; 4 bytes
FILE_HDL:           DS $02 ; 2 bytes
;FILE_BUF:           DS $81 ; 129 bytes

LINETMP:            DS $41 ; 65 bytes
LINEBUF:            DS $81 ; 129 bytes

;COFILEIDX:          DS $01 ; 1 byte
;OFNUMBER:           DS $01 ; 1 byte
;OFTABLE:            DS $0F ; 10 bytes
