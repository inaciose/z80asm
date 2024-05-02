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
; v1.05h - add peek
; v1.05i - global change to status codes (only)
; v1.06a - rewrite in order to get beter separation from operations and cli
;        - adding CLI and API entry points to routines
;        - adding memory variables - ERROR_CODE
;        - routine names relabeling:
;        - STARTRFN > FLOADFN
;        - STARTWFN > FSAVEFN
; v1.06b - Initial idle state check as routine (added to FSAVE, FLOAD)
; v1.06c - rewrite: FDEL, FREN, FCOPY, CD, CWD, MKDIR, RMDIR, RESET, SDIFS, FEXIST
; v1.06d - rewrite: FOPEN, FCLOSE, FWRITE, FREAD, FPEEK, FTELL, FSEEKSET, FSEEKCUR, FSEEKEND, FREWIND
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
SDCSWFN:            EQU   0x06 ; write file, send name 
SDCSWFD:            EQU   0x08 ; write file, send data
SDCSRFN:            EQU   0x02 ; read file, send name 
SDCSRFD:            EQU   0x04 ; read file, read data
SDCSDIRFN:          EQU   0x0a ; list send name ('\0' is current dir)
SDCSDIR:            EQU   0x0c ; read list data
SDCSDFN:            EQU   0x0e ; delete file, send name
SDCSRENFN1:         EQU   0x10 ; rename, send source 
SDCSRENFN2:         EQU   0x12 ; rename, send dest
SDCSCPYFN1:         EQU   0x14 ; copy, send source 
SDCSCPYFN2:         EQU   0x16 ; copy, send dest
SDCSEXISFN:         EQU   0x18 ; exist file?, send name 
SDCSEXIST:          EQU   0x1a ; exist file?, read data 
SDCSMKDFN:          EQU   0x1c ; mkdir, send name
SDCSRMDFN:          EQU   0x1e ; rmdir, send name
SDCSCHDFN:          EQU   0x20 ; chdir, send name
SDCSCWD:            EQU   0x22 ; cwd, read data (full path name)
SDCSFOFN:           EQU   0x24 ; file open file name
SDCSFOFM:           EQU   0x26 ; file open file mode
SDCSCFOGH:          EQU   0x28 ; file open get handle
SDCSCFHDL:          EQU   0x2a ; file close handle
SDCSFWHDL:          EQU   0x2c ; file write handle
SDCSFWRITE:         EQU   0x2e ; file write
SDCSFWSTAT:         EQU   0x30 ; file write status
SDCSFRHDL:          EQU   0x32 ; file read handle
SDCSFREAD:          EQU   0x34 ; file read
SDCSFRSTAT:         EQU   0x36 ; file read status
SDCSFGPHDL:         EQU   0x38 ; file get position handle
SDCSFGPOS:          EQU   0x3a ; file get position
SDCSFSSHDL:         EQU   0x3c ; file seekset handle
SDCSSEKSET:         EQU   0x3e ; file seekset
SDCSFSSSTAT:        EQU   0x40 ; file seekset status
SDCSFSCHDL:         EQU   0x42 ; file seekcur handle
SDCSSEKCUR:         EQU   0x44 ; file seekcur
SDCSFSCSTAT:        EQU   0x46 ; file seekcur statuts
SDCSFSEHDL:         EQU   0x48 ; file seekend handle
SDCSSEKEND:         EQU   0x4a ; file seekend
SDCSFSESTAT:        EQU   0x4c ; file seekend status
SDCSFRWDHDL:        EQU   0x4e ; file rewind handle
SDCSFPKHDL:         EQU   0x50 ; file peek handle
SDCSFPEEK:          EQU   0x52 ; file peek

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
SDCMDFPEEK:          EQU   0x29

;
;
; try to mantain a stable
; address to calling routines
; api call jump table 
;
CLIENTRY:            jp MAIN
APIFSAVE:            jp FSAVEAPI
APIFLOAD:            jp FLOADAPI
APIFDEL:             jp FDELAPI
APILIST:             jp STARTLSTF
APIFREN:             jp FRENAPI
APIFCOPY:            jp FCOPYAPI
APICHDIR:            jp CDAPI
APICWD:              jp CWDNAPI
APIMKDIR:            jp MKDIRAPI
APIRMDIR:            jp RMDIRAPI
APIEXIST:            jp FEXISTAPI
APIRESET:            jp SDIFRESETAPI
APIGETSDIFS:         jp GETSDIFSAPI
APIFOPEN:            jp FOPENAPI
APIFCLOSE:           jp FCLOSEAPI
APIFWRITE:           jp FWRITEAPI
APIFREAD:            jp FREADAPI
APIFTELL:            jp FTELLAPI
APIFSEEKSET:         jp FSEEKSETAPI
APIFSEEKCUR:         jp FSEEKCURAPI
APIFSEEKEND:         jp FSEEKENDAPI
APIFREWIND:          jp FREWINDAPI
APIFPEEK:            jp FPEEKAPI

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

;call FLOADCLI
MAIN_CHK2:
                    ld hl, CMD_LOAD
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK3
                    
                    ; dispatch
                    call FLOADCLI
                    
                    jp MAIN_END

;call FRENCLI
MAIN_CHK3:
                    ld hl, CMD_REN
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK4
                    
                    ; dispatch
                    call FRENCLI
                    
                    jp MAIN_END

;call FCOPYCLI
MAIN_CHK4:
                    ld hl, CMD_COPY
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK5
                    
                    ; dispatch
                    call FCOPYCLI
                    
                    jp MAIN_END

;call FEXISTCLI
MAIN_CHK5:
                    ld hl, CMD_EXIST
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK6
                    
                    ; dispatch
                    call FEXISTCLI
                    
                    jp MAIN_END

;call MKDIRCLI
MAIN_CHK6:
                    ld hl, CMD_MKDIR
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK7
                    
                    ; dispatch
                    call MKDIRCLI
                    
                    jp MAIN_END

;call RMDIRCLI
MAIN_CHK7:
                    ld hl, CMD_RMDIR
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK8
                    
                    ; dispatch
                    call RMDIRCLI
                    
                    jp MAIN_END

;call CDCLI
MAIN_CHK8:
                    ld hl, CMD_CD
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK9
                    
                    ; dispatch
                    call CDCLI
                    
                    jp MAIN_END

;call CWDNCLI
MAIN_CHK9:
                    ld hl, CMD_CWD
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK10
                    
                    ; dispatch
                    call CWDNCLI
                    
                    jp MAIN_END


MAIN_CHK10:
                    ld hl, CMD_EXIT
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK11
                    
                    ; dispatch
                    jp MAIN_RETURN

;call FEXISTCLI
MAIN_CHK11:
                    ;ld hl, CMD_EXIST
                    ;ld de, FILE_CMD
                    
                    ;call STRCMP
                    ;jr nz, MAIN_CHK12
                    
                    ; dispatch
                    ;call FEXISTCLI
                
                    ;jp MAIN_END
;call SDIFRESETCLI
MAIN_CHK12:
                    ld hl, CMD_RESET
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK13
                    
                    ; dispatch
                    call SDIFRESETCLI
                                        
                    jp MAIN_END

;call GETSDIFSCLI
MAIN_CHK13:
                    ld hl, CMD_SDIFS
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK14
                    
                    ; dispatch
                    call GETSDIFSCLI
                                        
                    jp MAIN_END

;call FDELCLI
MAIN_CHK14:
                    ld hl, CMD_DEL
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK15

                    ; dispatch
                    call FDELCLI

                    jp MAIN_END

;call FOPENCLI
MAIN_CHK15:
                    ld hl, CMD_FOPEN
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK16

                    ; dispatch
                    call FOPENCLI

                    jp MAIN_END

;call FCLOSECLI
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
                    call FCLOSECLI

                    jp MAIN_END

;call FWRITECLI
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
                    call FWRITECLI

                    jp MAIN_END

;class FREADCLI
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
                    call FREADCLI

                    jp MAIN_END

;call FTELLCLI
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
                    call FTELLCLI

                    jp MAIN_END

;call FSEEKSETCLI
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
                    call FSEEKSETCLI

                    jp MAIN_END

;call FSEEKCURCLI
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
                    call FSEEKCURCLI

                    jp MAIN_END

;call FSEEKENDCLI
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
                    call FSEEKENDCLI

                    jp MAIN_END

;call FREWINDCLI
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
                    call FREWINDCLI

                    jp MAIN_END

;call FPEEKCLI
MAIN_CHK24:
                    ld hl, CMD_FPEEK
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK25

                    ; prepare dispatch
                    ; FILE_NAME to numeric 
                    ; bin at FILE_HDL
                    call FNAME2FHDL

                    ; dispatch
                    call FPEEKCLI

                    jp MAIN_END
; call FSAVECLI
MAIN_CHK25:
                    ld hl, CMD_SAVE
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_END
                    
                    ; dispatch
                    call FSAVECLI

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
;--------------------------------------------------------
FDELCLI:
                    ;
                    ; entry point from cli
                    ;
                    call FDELFN

                    ; check for operation result
                    cp 0x00
                    jr z, FDELCLI_OK

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                 

FDELCLI_OK:
                    ; display ok end message
                    ; using scm api
                    ld   de,STR_REMOK
                    ld   C,$06
                    rst   $30
                    ret

;--------------------------------------------------------
;--------------------------------------------------------
FDELAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    

FDELFN:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,FDELFN_OK1
; just info
FDELFN_FAIL1:
                    ret

FDELFN_OK1:
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

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSDFN
                    jr   z,FDELFN_OK2

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x02
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl
                   
                    ret                     
                    
FDELFN_OK2:
                    ;
                    ; ready to send the file name
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

                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSIDL
                    jr   z, FDEL_OK
                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x03
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret
                    
FDEL_OK:
                    ;
                    ; operation ok
                    ;

                    ld a, 0x00
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
;--------------------------------------------------------
FSAVECLI:
                    ;
                    ; entry point from cli
                    ;
                    call FSAVEFN

                    ; check for operation result
                    cp 0x00
                    jr z, FSAVECLI_OK

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                 

FSAVECLI_OK:
                    ; display ok end message
                    ; using scm api
                    ld   de,STR_SAVEOK
                    ld   C,$06
                    rst   $30
                    ret

;--------------------------------------------------------
;--------------------------------------------------------
FSAVEAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    
FSAVEFN:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,FSAVEFN_OK1 

; just info
FSAVEFN_FAIL1:
                    ret

FSAVEFN_OK1:
                    ;
                    ; sdif status is ok to proceed
                    ;                    
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
                    
                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; check sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSWFN
                    jr   z,FSAVEFN_OK2
                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x02
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                      
                    
FSAVEFN_OK2:
                    ;
                    ; ready to send the file name
                    ; send the file name
                    ;
                    push    bc
                    push    hl
                    ld   hl,FILE_NAME
                    call    SENDFNAME   
                    pop     hl
                    pop     bc
                    
; just info
FSAVEWD:      
                    ;
                    ; filename sent check if
                    ; its ok to proceed
                    ;

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
                    jr   z, FSAVEWD_OK
                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x03
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret


FSAVEWD_OK:
                    ;
                    ; ready to save data on file
                    ;
                    
                    ; point hl to start of memory
                    ld hl,FILE_START
                    ld d, (hl)
                    inc hl
                    ld e, (hl)
                    ; need to get de in hl
                    ld h, d
                    ld l, e

                    push hl
                    ;
                    ld hl,FILE_LEN
                    ld d, (hl)
                    inc hl
                    ld e, (hl)
                    ;
                    pop hl
                                        
                    ld   c,SDCWD 
                    
FSAVEWDLOOP:      
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
                    
                    ; check if de is zero
                    ;push a
                    ld a, d
                    or e
                    ;pop a
                    
                    ; not zero
                    jr   nz,FSAVEWDLOOP 
                                        
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
FSAVEWDEND:
                    ;
                    ; operation done
                    ; check the status
                    ;
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
                    jr   z,FSAVEWDEND_OK                    

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x03
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret

FSAVEWDEND_OK:                    
                    ;
                    ; operation ok
                    ;
                    ld a, 0x00
                    ret

                    
;--------------------------------------------------------
;
; Load file from SD
;
;--------------------------------------------------------
;--------------------------------------------------------
FLOADCLI:
                    ;
                    ; entry point from cli
                    ;
                    call FLOADFN

                    ; check for operation result
                    cp 0x00
                    jr z, FLOADCLI_OK

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                 

FLOADCLI_OK:
                    ; display ok end message
                    ; using scm api
                    ld   de,STR_LOADOK
                    ld   C,$06
                    rst   $30
                    ret

;--------------------------------------------------------
;--------------------------------------------------------
FLOADAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    
FLOADFN:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,FLOADFN_OK1 
; just info
FLOADFN_FAIL:
                    ret

FLOADFN_OK1:
                    ;
                    ; iff status is ok to proceed
                    ;                    
                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; start load file
                    ; load cmd code in a, see equs
                    ld   a,SDCMDLOAD    
                    out   (SDCWC),a

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; check sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSRFN
                    jr   z,FLOADFN_OK2
                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x02
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                    
                    
FLOADFN_OK2:
                    ;
                    ; ready to send the file name
                    ; send the file name
                    ;
                    push bc
                    push hl
                    ld   hl,FILE_NAME
                    call SENDFNAME   
                    pop  hl
                    pop  bc
                    
; just info
FLOADRD:
                    ;
                    ; filename sent check if
                    ; its ok to proceed
                    ;
                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; check sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSRFD
                    jr   z, FLOADRD_OK
                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x03
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret
                    
FLOADRD_OK:                    
                    ;
                    ; ready to load the file data
                    ;
                    
                    ; point hl to start of memory
                    ld hl,FILE_START
                    ld d, (hl)
                    inc hl
                    ld e, (hl)
                    ; need to get de in hl
                    ld h, d
                    ld l, e
                    
                    ; init bytes loaded counter
                    ld de, 0x0000
FLOADRDLOOP:      
                    ; wait 1 ms before any
                    ; in or out to SD card
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
                    jr  nz, FLOADRDEND   
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
                    jr   nz,FLOADRDLOOP 

FLOADRDEND:
                    ;
                    ; operation ok
                    ; the file is loaded
                    ; set output variables 
                    ;
                    ; store num bytes loaded
                    push hl
                    ld hl, NUM_BYTES
                    ld (hl),d
                    inc hl
                    ld (hl),e
                    pop hl

                    ; the ERROR_CODE should be zero
                    ; no need to update it

                    ld a, 0x00
                    ret

;--------------------------------------------------------
;
; Rename file on SD
;
;--------------------------------------------------------
;--------------------------------------------------------
FRENCLI:
                    ;
                    ; entry point from cli
                    ;
                    call FRENFN

                    ; check for operation result
                    cp 0x00
                    jr z, FRENCLI_OK

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                 

FRENCLI_OK:
                    ; display ok end message
                    ; using scm api
                    ld   de,STR_RENOK
                    ld   C,$06
                    rst   $30
                    ret

;--------------------------------------------------------
;--------------------------------------------------------
FRENAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    
FRENFN:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,FRENFN_OK1

; just info
FRENFN_FAIL1:
                    ret

FRENFN_OK1:
                    ;
                    ; iff status is ok to proceed
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
                    
                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSRENFN1
                    jr   z,FRENFN_OK2

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x02
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                    
                    
FRENFN_OK2:
                    ;
                    ; ready to send the
                    ; source file name
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

                    ; get sdif status
                    in   a,(SDCRS)   
                    ; is rn file destination state ?
                    cp   SDCSRENFN2
                    jr   z, FRENFN_OK3
                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x03
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                    

FRENFN_OK3:
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
                    jr   z, FRENFN_OK
                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x04
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret

FRENFN_OK:                    
                    ;
                    ; operation ok
                    ;

                    ld a, 0x00
                    ret
;--------------------------------------------------------
;
; Copy file on SD
;
;--------------------------------------------------------
;--------------------------------------------------------
FCOPYCLI:
                    ;
                    ; entry point from cli
                    ;
                    call FCOPYFN

                    ; check for operation result
                    cp 0x00
                    jr z, FCOPYCLI_OK

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                 

FCOPYCLI_OK:
                    ; display ok end message
                    ; using scm api
                    ld   de,STR_COPYOK
                    ld   C,$06
                    rst   $30
                    ret

;--------------------------------------------------------
;--------------------------------------------------------
FCOPYAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    
FCOPYFN:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,FCOPYFN_OK1 

; just info
FCOPYFN_FAIL1:

                    ret

FCOPYFN_OK1:
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

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSCPYFN1
                    jr   z,FCOPYFN_OK2

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x02
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                    
                    
FCOPYFN_OK2:

                    ;
                    ; ready to send the
                    ; source file name
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

                    ; get sdif status
                    in   a,(SDCRS)   
                    ; is rn file destination state ?
                    cp   SDCSCPYFN2
                    jr   z, FCOPYFN_OK3

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x03
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret

FCOPYFN_OK3:
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

                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSIDL
                    jr   z, FCOPYFN_OK
                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x04
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret

FCOPYFN_OK:                    
                    ;
                    ; operation ok
                    ;

                    ld a, 0x00
                    ret
;--------------------------------------------------------
;
; CD on SD
;
;--------------------------------------------------------
;--------------------------------------------------------
CDCLI:
                    ;
                    ; entry point from cli
                    ;
                    call CDDN

                    ; check for operation result
                    cp 0x00
                    jr z, CDCLI_OK

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                 

CDCLI_OK:
                    ; display ok end message
                    ; using scm api
                    ld   de,STR_CHDIROK
                    ld   C,$06
                    rst   $30
                    ret

;--------------------------------------------------------
;--------------------------------------------------------
CDAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    
CDDN:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,CDDN_OK1

; just info
CDDN_FAIL1:
                    ret

CDDN_OK1:
                    ;
                    ; sdif status is ok to proceed
                    ;
                    
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

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSCHDFN
                    jr   z,CDDN_OK2

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x02
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                    
                    
CDDN_OK2:
                    ;
                    ; ready to send the file name
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

                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSIDL
                    jr   z, CDDN_OK
                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x03
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret
                    
CDDN_OK:                    
                    ;
                    ; operation ok
                    ;
                    ld a, 0x00
                    ret

;--------------------------------------------------------
;
; Get current working directory full path name (cwd)
;
;--------------------------------------------------------
;--------------------------------------------------------
CWDNCLI:
                    ;
                    ; entry point from cli
                    ;
                    call CWDN

                    ; check for operation result
                    cp 0x00
                    jr z, CWDNCLI_OK

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                 

CWDNCLI_OK:
                    ; display result
                    ; using scm api
                    ld   de,OUTBUFFER
                    ld   C,$06
                    rst   $30

                    ; output nl & cr
                    ld a, '\n'
                    call OUTCHAR
                    ld a, '\r'
                    call OUTCHAR  

                    ; display ok end message
                    ; using scm api
                    ld   de,STR_CWDOK
                    ld   C,$06
                    rst   $30
                    ret

;--------------------------------------------------------
;--------------------------------------------------------
CWDNAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    
CWDN:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,CWDN_OK1 

; just info
CWDN_FAIL1:
                    ret

CWDN_OK1:
                    ;
                    ; sdif status is ok to proceed
                    ; 
                    
                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; start get current directory name
                    ; load cmd code in a, see equs
                    ld   a,SDCMDCWD   
                    out   (SDCWC),a
                    
                    ; wait many ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 200
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; set pointer to the output
                    ; buffer start address
                    ld hl, OUTBUFFER
                    
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
  
                    ; got current directory name 
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
                    ;call OUTCHAR 

                    ; store char
                    ld (hl), a                   
                    
                    ; increment outbuffer pointer
                    inc hl

                    jr CWDNLOOP
                      
                    
CWDNEND_OK:
                    ;
                    ; operation ok
                    ; set output variablles
                    ;
                    ; store string terminator char
                    ld (hl), '\0' 
                    
                    ld a, 0x00
                    ret


;--------------------------------------------------------
;
; Make directory on SD (mkdir)
;
;--------------------------------------------------------
;--------------------------------------------------------
MKDIRCLI:
                    ;
                    ; entry point from cli
                    ;
                    call MKDIRN

                    ; check for operation result
                    cp 0x00
                    jr z, MKDIRCLI_OK

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                 

MKDIRCLI_OK:
                    ; display ok end message
                    ; using scm api
                    ld   de,STR_MKDIROK
                    ld   C,$06
                    rst   $30
                    ret

;--------------------------------------------------------
;--------------------------------------------------------
MKDIRAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    

MKDIRN:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,MKDIRN_OK1 

; just info
MKDIRN_FAIL1:
                    ret

MKDIRN_OK1:
                    ;
                    ; sdif status is ok to proceed
                    ;
                    
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

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSMKDFN
                    jr   z,MKDIRN_OK2

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x02
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                    
                    
MKDIRN_OK2:
                    ;
                    ; ready to send the file name
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

                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSIDL
                    jr   z, MKDIRN_OK
                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x03
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret
                    
MKDIRN_OK:                    
                    ;
                    ; operation ok
                    ;

                    ld a, 0x00
                    ret

;--------------------------------------------------------
;
; Remove directory on SD (mkdir)
;
;--------------------------------------------------------
;--------------------------------------------------------
RMDIRCLI:
                    ;
                    ; entry point from cli
                    ;
                    call RMDIRN

                    ; check for operation result
                    cp 0x00
                    jr z, RMDIRCLI_OK

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                 

RMDIRCLI_OK:
                    ; display ok end message
                    ; using scm api
                    ld   de,STR_RMDIROK
                    ld   C,$06
                    rst   $30
                    ret

;--------------------------------------------------------
;--------------------------------------------------------
RMDIRAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    

RMDIRN:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,RMDIRN_OK1 
 
; just info
RMDIRN_FAIL1:
                    ret

RMDIRN_OK1:
                    ;
                    ; sdif status is ok to proceed
                    ;
                    
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

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSRMDFN
                    jr   z,RMDIRN_OK2

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x02
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                     
                    
RMDIRN_OK2:
                    ;
                    ; ready to send the file name
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

                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSIDL
                    jr   z, RMDIRN_OK
                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x03
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret
                    
RMDIRN_OK:                    
                    ;
                    ; operation ok
                    ;

                    ld a, 0x00
                    ret

;--------------------------------------------------------
;
; Reset the SD card interface, status > 0x00 (reset)
;
;--------------------------------------------------------
;--------------------------------------------------------
SDIFRESETCLI:
                    ;
                    ; entry point from cli
                    ;
                    call SDIFRESET

                    ; check for operation result
                    cp 0x00
                    jr z, SDIFRESETCLI_OK

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                 

SDIFRESETCLI_OK:
                    ; display ok end message
                    ; using scm api
                    ld   de,STR_RESETOK
                    ld   C,$06
                    rst   $30
                    ret

;--------------------------------------------------------
;--------------------------------------------------------
SDIFRESETAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    

SDIFRESET:
                    ; reset error code
                    ld hl, ERROR_CODE
                    ld (hl), 0x00

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

                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSIDL
                    jr   z,SDIFRESET_OK

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x01
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret            

SDIFRESET_OK:                    
                    ;
                    ; operation ok
                    ;

                    ld a, 0x00
                    ret

;--------------------------------------------------------
;
; Get the SD card interface status (sdifs)
;
;--------------------------------------------------------
;--------------------------------------------------------
GETSDIFSCLI:
                    ;
                    ; entry point from cli
                    ;
                    call GETSDIFS

                    ; check for operation result
                    cp 0x00
                    jr z, GETSDIFSCLI_OK

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                 

GETSDIFSCLI_OK:
                    ;
                    ; display result
                    ;

                    ; read memory variable
                    ld hl, OUT_BYTE
                    ld a, (hl)

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

                    ; and ok end message
                    ; using scm api
                    ld   de,STR_SDIFSOK
                    ld   C,$06
                    rst   $30
                    ret

;--------------------------------------------------------
;--------------------------------------------------------
GETSDIFSAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    
GETSDIFS: 
                    ; reset error code
                    ld hl, ERROR_CODE
                    ld (hl), 0x00

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; get status
                    in   a,(SDCRS)   

                    ; store data in memory
                    ld hl, OUT_BYTE
                    ld (hl), a         

                    ;
                    ; operation ok
                    ;

                    ld a, 0x00
                    ret

;--------------------------------------------------------
;
; Check if file exists
;
;--------------------------------------------------------
;--------------------------------------------------------
FEXISTCLI:
                    ;
                    ; entry point from cli
                    ;
                    call FEXISTFN

                    ; check for operation result
                    cp 0x00
                    jr z, FEXISTCLI_OK

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                 

FEXISTCLI_OK:
                    ;
                    ; display result
                    ;

                    ; read memory variable
                    ld hl, OUT_BYTE
                    ld a, (hl)

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
                     
                    ; and ok end message
                    ; using scm api
                    ld   de,STR_SDIFSOK
                    ld   C,$06
                    rst   $30
                    ret

;--------------------------------------------------------
;--------------------------------------------------------
FEXISTAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    
FEXISTFN:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,FEXISTFN_OK1 
; just info
FEXISTFN_FAIL1:
                    ret

FEXISTFN_OK1:
                    ;
                    ; sdif status is ok to proceed
                    ; 
                    
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

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSEXISFN
                    jr   z,FEXISTFN_OK2
                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x02
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                    

FEXISTFN_OK2:
                    ;
                    ; ready to send the file name
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

                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSEXIST
                    jr   z, FEXISTFN_OK3
                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x03
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret 

FEXISTFN_OK3:
                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; get data
                    in   a,(SDCRD)

                    ; store data in memory
                    ld hl, OUT_BYTE
                    ld (hl), a

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSIDL
                    jr   z, FEXISTFN_OK

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x04
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret

FEXISTFN_OK:                    
                    ;
                    ; operation ok
                    ;

                    ld a, 0x00
                    ret

;--------------------------------------------------------
;
; File open on SD, with name & mode - int ofhld = fopen (char *fn, int32 *mode)
;
;--------------------------------------------------------
;--------------------------------------------------------
FOPENCLI:
                    ;
                    ; entry point from cli
                    ;
                    call FOPENFN

                    ; check for operation result
                    cp 0x00
                    jr z, FOPENCLI_OK

                    ; display error code

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

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                 

FOPENCLI_OK:
                    ;
                    ; display result
                    ;

                    ; read memory variable
                    ld hl, OUT_BYTE
                    ld a, (hl)

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

                    ; and ok end message
                    ; using scm api
                    ld   de,STR_OK
                    ld   C,$06
                    rst   $30
                    ret

;--------------------------------------------------------
;--------------------------------------------------------
FOPENAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    
FOPENFN:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,FOPENFN_OK1 

; just info
FOPENFN_FAIL1:
                    ret

FOPENFN_OK1:
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

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl
                    
                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSFOFN
                    jr   z,FOPENFN_OK2

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x02
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                    
                    
FOPENFN_OK2:
                    ;
                    ; ready to send the
                    ; source file name
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

                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSFOFM
                    jr   z, FOPENFN_OK3
                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x03
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret

FOPENFN_OK3:
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
                   
                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSCFOGH
                    jr   z, FOPENFN_OK4  

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x04
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                 

FOPENFN_OK4:
                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get data
                    in   a,(SDCRD)   

                    ; register a have the file
                    ; handler id store it in memory
                    ld hl, OUT_BYTE
                    ld (hl), a

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSIDL
                    jr   z, FOPENFN_OK
                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x05
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret 

FOPENFN_OK:                    
                    ;
                    ; operation ok
                    ;

                    ld a, 0x00
                    ret

;--------------------------------------------------------
;
; File close on SD - fclose (int *ofhld)
;
;--------------------------------------------------------
;--------------------------------------------------------
FCLOSECLI:
                    ;
                    ; entry point from cli
                    ;
                    call FCLOSEHL

                    ; check for operation result
                    cp 0x00
                    jr z, FCLOSECLI_OK

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                 

FCLOSECLI_OK:
                    ;
                    ; display ok end message
                    ; using scm api
                    ld   de,STR_OK
                    ld   C,$06
                    rst   $30
                    ret

;--------------------------------------------------------
;--------------------------------------------------------
FCLOSEAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    
FCLOSEHL:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,FCLOSEHL_OK1 

; just info
FCLOSEHL_FAIL1:
                    ret

FCLOSEHL_OK1:
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

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl
                    
                    ; get sdif status
                    in   a,(SDCRS)   
                    ; its ok to proceed
                    cp   SDCSCFHDL
                    jr   z,FCLOSEHL_OK2

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x02
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret

FCLOSEHL_OK2:
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
                   
                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSIDL
                    jr   z, FCLOSEHL_OK3  

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x03
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                 

FCLOSEHL_OK3:
                    ;
                    ; operation ok
                    ;

                    ld a, 0x00
                    ret

;--------------------------------------------------------
;
; File write one byte - fwrite (int *ofhld, int b)
;
;--------------------------------------------------------
;--------------------------------------------------------
FWRITECLI:
                    ;
                    ; entry point from cli
                    ;
                    call FWRITEFH

                    ; check for operation result
                    cp 0x00
                    jr z, FWRITECLI_OK

                    ; display error code

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

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                 

FWRITECLI_OK:
                    ;
                    ; display result
                    ;

                    ; read memory variable
                    ld hl, OUT_BYTE1
                    ld a, (hl)

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

                    ; and ok end message
                    ; using scm api
                    ld   de,STR_OK
                    ld   C,$06
                    rst   $30
                    ret

;--------------------------------------------------------
;--------------------------------------------------------
FWRITEAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    
FWRITEFH:
                     ; check idle status                    
                    call SDCIDLECHK
                    jr   z,FWRITEFH_OK1

; just info
FWRITEFH_FAIL1:
                    ret

FWRITEFH_OK1:
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

                    ; start write byte to file
                    ; load cmd code in a, see equs
                    ld   a,SDCMDFWRITE   
                    out   (SDCWC),a

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl
                    
                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSFWHDL
                    jr   z,FWRITEFH_OK2

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x02
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret

FWRITEFH_OK2:
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
                   
                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSFWRITE
                    jr   z, FWRITEFH_OK3  

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x03
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                 

FWRITEFH_OK3:
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
                   
                    ; get sdif status
                    in   a,(SDCRS)   
                    ; is the send operation result state?
                    cp   SDCSFWSTAT
                    jr   z, FWRITEFH_OK4  

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x04
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                 

FWRITEFH_OK4:
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
                    
                    ; store data in memory 
                    ld hl, OUT_BYTE1
                    ld (hl), a

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl
                    
                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSIDL
                    jr   z, FWRITEFH_OK
                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x05
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret 

FWRITEFH_OK:
                    ;
                    ; operation ok
                    ;

                    ld a, 0x00
                    ret

;--------------------------------------------------------
;
; File read one byte - fread (int *ofhld)
;
;--------------------------------------------------------
;--------------------------------------------------------
FREADCLI:
                    ;
                    ; entry point from cli
                    ;
                    call FREADFH

                    ; check for operation result
                    cp 0x00
                    jr z, FREADCLI_OK

                    ; display error code

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

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                 

FREADCLI_OK:
                    ;
                    ; display result
                    ;

                    ; read memory variable
                    ld hl, OUT_BYTE1
                    ld a, (hl)

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
                    ; display readed char
                    ;

                    ; read memory variable
                    ld hl, OUT_BYTE
                    ld a, (hl)

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

                    ; and ok end message
                    ; using scm api
                    ld   de,STR_OK
                    ld   C,$06
                    rst   $30
                    ret

;--------------------------------------------------------
;--------------------------------------------------------
FREADAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    
FREADFH:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,FREADFH_OK1 

; just info
FREADFH_FAIL1:
                    ret

FREADFH_OK1:
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
                    
                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSFRHDL
                    jr   z,FREADFH_OK2

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x02
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret

FREADFH_OK2:
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
                   
                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSFREAD
                    jr   z, FREADFH_OK3  

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x03
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                 

FREADFH_OK3:
                    ; read the byte from file

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get data
                    in   a,(SDCRD)   
                    
                    ; store data in memory 
                    ld hl, OUT_BYTE
                    ld (hl), a

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSFRSTAT
                    jr   z, FREADFH_OK4
                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x04
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret


FREADFH_OK4:
                    ; read operation result

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get data
                    in   a,(SDCRD)

                    ; store data in memory 
                    ld hl, OUT_BYTE1
                    ld (hl), a

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get sdif status
                    in   a,(SDCRS)   
                    ; is in idle state ?
                    cp   SDCSIDL
                    jp   z, FREADFH_OK
                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x05
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret

FREADFH_OK:
                    ;
                    ; operation ok
                    ;

                    ld a, 0x00
                    ret

;--------------------------------------------------------
;
; File peek one byte - fpeek (int *ofhld)
;
;--------------------------------------------------------
;--------------------------------------------------------
FPEEKCLI:
                    ;
                    ; entry point from cli
                    ;
                    call FPEEKFH

                    ; check for operation result
                    cp 0x00
                    jr z, FPEEKCLI_OK

                    ; display error code

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

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                 

FPEEKCLI_OK:
                    ;
                    ; display peeked char
                    ;

                    ; read memory variable
                    ld hl, OUT_BYTE
                    ld a, (hl)

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

                    ; and ok end message
                    ; using scm api
                    ld   de,STR_OK
                    ld   C,$06
                    rst   $30
                    ret

;--------------------------------------------------------
;--------------------------------------------------------
FPEEKAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    
FPEEKFH:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,FPEEKFH_OK1 

; just info
FPEEKFH_FAIL1:
                    ret

FPEEKFH_OK1:
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
                    ld   a,SDCMDFPEEK   
                    out   (SDCWC),a
                    
                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl
                    
                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSFPKHDL
                    jr   z,FPEEKFH_OK2

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x02
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret 

FPEEKFH_OK2:
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
                   
                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSFPEEK
                    jr   z, FPEEKFH_OK3  

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x03
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret 
                  

FPEEKFH_OK3:
                    ; read the byte from file

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get data
                    in   a,(SDCRD)   
                    
                    ; store data in memory
                    ld hl, OUT_BYTE
                    ld (hl), a

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSIDL
                    jr   z, FPEEKFH_OK
                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x04
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret 

FPEEKFH_OK:
                    ;
                    ; operation ok
                    ;

                    ld a, 0x00
                    ret

;--------------------------------------------------------
;
; Get file current position - fcurpos (int *ofhld)
;
;--------------------------------------------------------
;--------------------------------------------------------
FTELLCLI:
                    ;
                    ; entry point from cli
                    ;
                    call FTELLFH

                    ; check for operation result
                    cp 0x00
                    jr z, FTELLCLI_OK

                    ; display error code

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

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                 

FTELLCLI_OK:
                    ;
                    ; display peeked char
                    ;

                    ; read memory variable
                    ld hl, OUT_LONG
                    ld a, (hl)

                    ; byte 4
                    push hl

                    ; convert to hex
                    call NUM2HEX;

                    ; display hex
                    ld a, d
                    call OUTCHAR 
                    ld a, e
                    call OUTCHAR

                    pop hl

                    ; byte 3
                    inc hl
                    ld a, (hl)
                    push hl 

                    ; convert to hex
                    call NUM2HEX;

                    ; display hex
                    ld a, d
                    call OUTCHAR 
                    ld a, e
                    call OUTCHAR

                    pop hl

                    ; byte 2
                    inc hl
                    ld a, (hl)
                    push hl 

                    ; convert to hex
                    call NUM2HEX;

                    ; display hex
                    ld a, d
                    call OUTCHAR 
                    ld a, e
                    call OUTCHAR

                    pop hl

                    ; byte 1 (last)
                    inc hl
                    ld a, (hl)
                    push hl

                    ; convert to hex
                    call NUM2HEX;

                    ; display hex
                    ld a, d
                    call OUTCHAR 
                    ld a, e
                    call OUTCHAR

                    pop hl 


                    ld a, '\n'
                    call OUTCHAR 
                    ld a, '\r'
                    call OUTCHAR

                    ; and ok end message
                    ; using scm api
                    ld   de,STR_OK
                    ld   C,$06
                    rst   $30
                    ret

;--------------------------------------------------------
;--------------------------------------------------------
FTELLAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    
FTELLFH:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,FTELLFH_OK1

; just info
FTELLFH_FAIL1:
                    ret

FTELLFH_OK1:
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
                    
                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSFGPHDL
                    jr   z,FTELLFH_OK2

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x02
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret

FTELLFH_OK2:
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
                    jr   z, FTELLFH_OK3  

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x03
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                  

FTELLFH_OK3:
                    ; set variable top
                    ; memory address
                    ld hl, OUT_LONG
                    inc hl
                    inc hl
                    inc hl

FTELLFH_LOOP:
                    ; read pos byte from file

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get data
                    in   a,(SDCRD)   
                    
                    ; store data in
                    ; memory address
                    ld (hl), a
                    dec hl

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get status
                    in   a,(SDCRS)   
                    ; are bytes available ?
                    cp   SDCSFGPOS
                    jr   z, FTELLFH_LOOP
                    
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

                    ; get sdif status
                    in   a,(SDCRS)   
                    ; is in idle state ?
                    cp   SDCSIDL
                    jr   z, FTELLFH_OK
                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x04
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret

FTELLFH_OK:
                    ;
                    ; operation ok
                    ;

                    ld a, 0x00
                    ret

;--------------------------------------------------------
;
; File position set - seekset (int *ofhld, int32 p)
;
;--------------------------------------------------------
;--------------------------------------------------------
FSEEKSETCLI:
                    ;
                    ; entry point from cli
                    ;
                    call FSEEKSETFH

                    ; check for operation result
                    cp 0x00
                    jr z, FSEEKSETCLI_OK

                    ; display error code

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

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                 

FSEEKSETCLI_OK:
                    ;
                    ; display result
                    ;

                    ; read memory variable
                    ld hl, OUT_BYTE1
                    ld a, (hl)

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

                    ; and ok end message
                    ; using scm api
                    ld   de,STR_OK
                    ld   C,$06
                    rst   $30
                    ret

;--------------------------------------------------------
;--------------------------------------------------------
FSEEKSETAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    
FSEEKSETFH:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,FSEEKSETFH_OK1

; just info
FSEEKSETFH_FAIL1:
                    ret

FSEEKSETFH_OK1:
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

                    ; start operation
                    ; load cmd code in a, see equs
                    ld   a,SDCMDFSEKSET   
                    out   (SDCWC),a
                    
                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl
                    
                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSFSSHDL
                    jr   z,FSEEKSETFH_OK2

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x02
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret 

FSEEKSETFH_OK2:
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
                   
                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSSEKSET
                    jr   z, FSEEKSETFH_OK3  

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x03
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                 

FSEEKSETFH_OK3:
                    ; ready to send the four bytes (32bits)
                    ; to set position on file

                    ; we use:
                    ; - FILE_START 16bits
                    ; - FILE_LEN 16bits

                    ;
                    ; first the FILE_START
                    ;

                    ; wait 1 ms before any
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

                   
                    ; get sdif status
                    in   a,(SDCRS)   
                    ; is the send operation result state?
                    cp   SDCSFSSSTAT
                    jr   z, FSEEKSETFH_OK4  

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x04
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                  

FSEEKSETFH_OK4:
                    ; read operation result

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get data
                    in   a,(SDCRD)   
                    
                    ; store data in memory
                    ld hl, OUT_BYTE1
                    ld (hl), a

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSIDL
                    jr   z, FSEEKSETFH_OK
                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x05
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret

FSEEKSETFH_OK:
                    ;
                    ; operation ok
                    ;

                    ld a, 0x00
                    ret

;--------------------------------------------------------
;
; File position set - seekcur (int *ofhld, int32 p)
;
;--------------------------------------------------------
;--------------------------------------------------------
FSEEKCURCLI:
                    ;
                    ; entry point from cli
                    ;
                    call FSEEKCURFH

                    ; check for operation result
                    cp 0x00
                    jr z, FSEEKCURCLI_OK

                    ; display error code

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

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                 

FSEEKCURCLI_OK:
                    ;
                    ; display result
                    ;

                    ; read memory variable
                    ld hl, OUT_BYTE1
                    ld a, (hl)

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

                    ; and ok end message
                    ; using scm api
                    ld   de,STR_OK
                    ld   C,$06
                    rst   $30
                    ret

;--------------------------------------------------------
;--------------------------------------------------------
FSEEKCURAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    
FSEEKCURFH:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,FSEEKCURFH_OK1 

; just info
FSEEKCURFH_FAIL1:
                    ret

FSEEKCURFH_OK1:
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

                    ; start operation
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
                    
                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSFSCHDL
                    jr   z,FSEEKCURFH_OK2

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x02
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret

FSEEKCURFH_OK2:
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
                   
                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSSEKCUR
                    jr   z, FSEEKCURFH_OK3  

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x03
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                  

FSEEKCURFH_OK3:
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

                   
                    ; get sdif status
                    in   a,(SDCRS)   
                    ; is the send operation result state?
                    cp   SDCSFSCSTAT
                    jr   z, FSEEKCURFH_OK4  

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x04
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                  

FSEEKCURFH_OK4:
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
                    
                    ; store data in memory
                    ld hl, OUT_BYTE1
                    ld (hl), a

                    ; wait a ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get status
                    in   a,(SDCRS)   
                    ; is rn file destination state ?
                    cp   SDCSIDL
                    jr   z, FSEEKCURFH_OK
                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x05
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret

FSEEKCURFH_OK:
                    ;
                    ; operation ok
                    ;

                    ld a, 0x00
                    ret

;--------------------------------------------------------
;
; File position set - seekend (int *ofhld, int32 p)
;
;--------------------------------------------------------
;--------------------------------------------------------
FSEEKENDCLI:
                    ;
                    ; entry point from cli
                    ;
                    call FSEEKENDFH

                    ; check for operation result
                    cp 0x00
                    jr z, FSEEKENDCLI_OK

                    ; display error code

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

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                 

FSEEKENDCLI_OK:
                    ;
                    ; display result
                    ;

                    ; read memory variable
                    ld hl, OUT_BYTE1
                    ld a, (hl)

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

                    ; and ok end message
                    ; using scm api
                    ld   de,STR_OK
                    ld   C,$06
                    rst   $30
                    ret

;--------------------------------------------------------
;--------------------------------------------------------
FSEEKENDAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    
FSEEKENDFH:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,FSEEKENDFH_OK1 

; just info
FSEEKENDFH_FAIL1:
                    ret

FSEEKENDFH_OK1:
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
                    
                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSFSEHDL
                    jr   z,FSEEKENDFH_OK2

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x02
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret

FSEEKENDFH_OK2:
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
                   
                    ; get sdif status
                    in   a,(SDCRS)   
                    ; is the send mode state?
                    cp   SDCSSEKEND
                    jr   z, FSEEKENDFH_OK3  

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x03
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                 

FSEEKENDFH_OK3:
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

                   
                    ; get sdif status
                    in   a,(SDCRS)   
                    ; is the send operation result state?
                    cp   SDCSFSESTAT
                    jr   z, FSEEKENDFH_OK4  

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x04
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                  

FSEEKENDFH_OK4:
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
                    
                    ; store data in memory
                    ld hl, OUT_BYTE1
                    ld (hl), a

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get sdif status
                    in   a,(SDCRS)   
                    ; is rn file destination state ?
                    cp   SDCSIDL
                    jr   z, FSEEKENDFH_OK
                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x05
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret 

FSEEKENDFH_OK:
                    ;
                    ; operation ok
                    ;

                    ld a, 0x00
                    ret

;--------------------------------------------------------
;
; File position set - rewind (int *ofhld)
;
;--------------------------------------------------------
;--------------------------------------------------------
FREWINDCLI:
                    ;
                    ; entry point from cli
                    ;
                    call FREWINDFH

                    ; check for operation result
                    cp 0x00
                    jr z, FREWINDCLI_OK

                    ; display error code

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

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                 

FREWINDCLI_OK:
                    ;
                    ; display end message
                    ; using scm api
                    ld   de,STR_OK
                    ld   C,$06
                    rst   $30
                    ret

;--------------------------------------------------------
;--------------------------------------------------------
FREWINDAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    
FREWINDFH:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,FREWINDFH_OK1 

; just info
FREWINDFH_FAIL1:
                    ret

FREWINDFH_OK1:
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

                    ; start rewind file
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
                    
                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSFRWDHDL
                    jr   z,FREWINDFH_OK2

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x02
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret

FREWINDFH_OK2:
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
                   
                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSIDL
                    jr   z, FREWINDFH_OK 

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x03
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                  

FREWINDFH_OK:
                    ;
                    ; operation ok
                    ;

                    ld a, 0x00
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


;--------------------------------------------------------
; 
; Initial Check for idle status
;
;--------------------------------------------------------
; args: none
; return: register A have zero (success)
;         or error number one
SDCIDLECHK:
                    ;
                    ; reset ERROR_CODE
                    ;
                    ;push hl
                    ld hl, ERROR_CODE
                    ld (hl), 0x00
                    ;pop hl

                    ;
                    ; start checking iff state
                    ;
                    ; wait 1 ms before any
                    ; in or out to SD card
                    ;push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    ;pop hl
                    
                    ; get status
                    in   a,(SDCRS)   
                    ; exit with error message if a != 0
                    cp   SDCSIDL   
                    jr   z,SDCIDLECHK_OK 
; just info
SDCIDLECHK_FAIL:
                    ;
                    ; set error code and
                    ; return to caller
                    ;
                    ;push hl
                    ld a, 0x01
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret

SDCIDLECHK_OK:
                    ld a, 0x00

                    ret

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
CMD_FGETPOS:          DB      "FGETPOS",0 ;FTELL
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
;                    ORG    $FA00
                    ORG    $F000                  
RAMDATA:
; output
ERROR_CODE:         DS $01
OUT_BYTE:           DS $01
OUT_BYTE1:          DS $01
OUT_LONG:           DS $04 ; 4 bytes
NUM_BYTES:          DS $02 ; 2 bytes

; input
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

; output
OUTBUFFER:          DS $81 ; 129 bytes

;COFILEIDX:          DS $01 ; 1 byte
;OFNUMBER:           DS $01 ; 1 byte
;OFTABLE:            DS $0F ; 10 bytes
