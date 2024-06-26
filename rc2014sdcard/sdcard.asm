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
; v1.06e - add fcat and ram vars change
; v1.06f - firmare v1.06a - sync on fwrite byte (send result)
;          without the sync the reading, after close the file,
;          it is not ok. need to read twice. Like 'cat a.txt', after 'cat a.txt'
;          change its only the last delay on FWRITEFH_OK4
; v1.06g - cmd select improvement: add lenght compare
; v1.06h - add frwiteb (firmware v1.06b)
; v1.06i - add freadb & change frwiteb and frwite to wait for SDC on sync
; v1.06j - add ftruncate (firmware v1.06c )
; v1.06k - add lsof (firmware v1.06d)
; v1.06l - add getfsize (firmware v1.06e)
; v1.06m - add getfname (firmware v1.06f)
; v1.06n - rewrite list (firmware v1.06g), divided on list (cli), and slist & clist
; v1.06o - cleanup, slist & clist removed from cli (firmware v1.06g)
; v1.06p - add setorg, to set origin to load and run programs in only the program name
;          add run command on sdcard, filename must end with .com or .exe
;          (firmware v1.06g)
; v1.06q - minor fixes, changes & minor save space (firmware v1.06g)
; v1.06r - Added conditional assembler for cli low level file operations (firmware v1.06g)
; v1.06s - remove extra spaces from the command line (firmware v1.06g)
; v1.07a - add fdspace & tdspace (firmware v1.07a)
; v1.07b - add version to welcome & cosmetics (firmware v1.07a)
; v1.07c - add run command (like g in SCM) (firmware v1.07a)
;
; ATENTION!!!
; REMEMBER TO UPDATE VERSION STRING AT END

DEBUG:              EQU   0x01

                    ORG   $2000

; Connection to SD card device firmware
; Interface addresses used in operation
SDCRS:              EQU   0x40   ; read status
SDCRD:              EQU   0x41   ; read data from device
SDCWC:              EQU   0x40   ; write command
SDCWD:              EQU   0x41   ; write data to device

; Connection to SD card device firmware
; Firmware status codes for each situation
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
SDCSFWBHDL:         EQU   0x54 ; file writebytes handle
SDCSFWRITEB:        EQU   0x56 ; file writebytes
SDCSFWBSTAT:        EQU   0x58 ; file writebytes status
SDCSFRBHDL:         EQU   0x5A ; file readbytes handle
SDCSFREADB:         EQU   0x5C ; file readbytes
SDCSFRBSTAT:        EQU   0x5E ; file readbytes status
SDCSFTRCTHDL:       EQU   0x60 ; file truncate handle
SDCSFTRUNCATE:      EQU   0x62 ; file truncate
SDCSFTRCTSTAT:      EQU   0x64 ; file truncate status
SDCSLSOFRD:         EQU   0x66 ; list of open files
SDCSFGSIZEHDL:      EQU   0x68 ; get file size file handle
SDCSFGSIZE:         EQU   0x6A ; get file size
SDCSFGNAMEHDL:      EQU   0x6C ; get file name file handle
SDCSFGNAME:         EQU   0x6E ; get file name
SDCSTOTALSPACE:     EQU   0x72 ; get total space in sdcard
SDCSFREESPACE:      EQU   0x74 ; get free space in sdcard

; Connection to SD card device firmware
; Commands that initiate I/O operations
SDCMDRESET:          EQU   0x0f
SDCMDLOAD:           EQU   0x0d
SDCMDSAVE:           EQU   0x0c
SDCMDRWEND:          EQU   0x0b
SDCMDLIST:           EQU   0x0e
SDCMDCLIST:          EQU   0x1e
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
SDCMDFWRITEB:        EQU   0x2A
SDCMDFREADB:         EQU   0x2B
SDCMDFTRUNCATE:      EQU   0x2C
SDCMDLSOF:           EQU   0x2D
SDCMDFGETSIZE:       EQU   0x2E
SDCMDFGETNAME:       EQU   0x2F
SDCMDTOTALSPACE:     EQU   0x30
SDCMDFREESPACE:      EQU   0x31

; API call jump table
; maintains stable addresses 
; for calls to routines
CLIENTRY:            jr MAIN
APIFSAVE:            jp FSAVEAPI
APIFLOAD:            jp FLOADAPI
APIFDEL:             jp FDELAPI
APISLIST:            jp SLISTAPI ; start DIR
APICLIST:            jp CLISTAPI ; get each dir item
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
APIFWRITEB:          jp FWRITEBAPI
APIFREADB:           jp FREADBAPI
APIFTRUNCATE:        jp FTRUNCATEAPI
APILSOF:             jp LSOFAPI
APIFGETSIZE:         jp FGETSIZEAPI
APIFGETNAME:         jp FGETNAMEAPI
APIFDSPACE:          jp FDSPACEAPI
APITDSPACE:          jp TDSPACEAPI

; just info
MAIN:        
                    ;
                    ; set memory vars
                    ; 
        
                    ; set org for programs
                    ld hl, CLI_ORG
                    ld (hl), 0x80
                    inc hl
                    ld (hl), 0x00

                    ; output nl & cr
                    ld a, '\n'
                    call OUTCHAR
                    ld a, '\r'
                    call OUTCHAR
                    ld a, '\n'
                    call OUTCHAR

                    ; display welcome message
                    ; call api: print str
                    ld   de, STR_ZTGSDC
                    ld   c,$06
                    rst  $30

                    ; display version
                    ; call api: print str
                    ld   de, STR_ZTGVER
                    ld   c,$06
                    rst  $30

MAIN_LOOP:
          
                    ; display get cmd message
                    ; call api: print str
                    ld   de, STR_CMD
                    ld   C,$06
                    rst   $30 

                    ; init LINETMP to zero
                    ld hl,LINETMP
                    ld de,LINETMP+1
                    ld bc, 0x0041
                    ld (hl), 0x00
                    ldir

                    ; init LINEBUF to zero
                    ld hl,LINEBUF
                    ld de,LINEBUF+1
                    ld bc, 0x0091
                    ld (hl), 0x00
                    ldir

                    ; get cmd string from user
                    ; call api: get input
                    ld de, LINEBUF
                    ld a, $91 ; load string len + 1 (for terminator)
                    ld c, $04
                    rst   $30

                    ; load string start address
                    ld hl,LINEBUF
                    ; remove extra spaces
                    call DELEXSRTSPC

                    ; parse the line extracting
                    ; the command and arguments
                    call LINE_PARSE

                    ;
                    ; dispatch cmd
                    ; by sequentialy 
                    ; compare hl with de
                    ; hl have the command
                    ; de have the input to be tested
                    
                    ; dummy check to handle 
                    ; return key only
                    ; the '\0' on FILE_CMD
                    ; match the compare
                    ld hl, CMD_RET
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_NLCR

                    ; dispatch
                    jp MAIN_END

MAIN_NLCR:
                    ; output nl & cr
                    ld a, '\n'
                    call OUTCHAR
                    ld a, '\r'
                    call OUTCHAR

                    ; continue checking
                    ; valid commands                   
             
;call LISTCLI
MAIN_CHK1:
                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_LIST
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK2

                    ; ok same lenght
                    ld hl, CMD_LIST
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK2
                    
                    ; dispatch
                    call LISTCLI
                    
                    jp MAIN_END

;call FLOADCLI
MAIN_CHK2:
                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_LOAD
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK3

                    ; ok same lenght
                    ld hl, CMD_LOAD
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK3
                    
                    ; dispatch
                    call FLOADCLI
                    
                    jp MAIN_END

;call FRENCLI
MAIN_CHK3:
                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_REN
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK4

                    ; ok same lenght
                    ld hl, CMD_REN
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK4
                    
                    ; dispatch
                    call FRENCLI
                    
                    jp MAIN_END

;call FCOPYCLI
MAIN_CHK4:
                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_COPY
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK5

                    ; ok same lenght
                    ld hl, CMD_COPY
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK5
                    
                    ; dispatch
                    call FCOPYCLI
                    
                    jp MAIN_END

;call FEXISTCLI
MAIN_CHK5:
                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_EXIST
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK6

                    ; ok same lenght
                    ld hl, CMD_EXIST
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK6
                    
                    ; dispatch
                    call FEXISTCLI
                    
                    jp MAIN_END

;call MKDIRCLI
MAIN_CHK6:
                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_MKDIR
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK7

                    ; ok same lenght
                    ld hl, CMD_MKDIR
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK7
                    
                    ; dispatch
                    call MKDIRCLI
                    
                    jp MAIN_END

;call RMDIRCLI
MAIN_CHK7:
                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_RMDIR
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK8

                    ; ok same lenght
                    ld hl, CMD_RMDIR
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK8
                    
                    ; dispatch
                    call RMDIRCLI
                    
                    jp MAIN_END

;call CDCLI
MAIN_CHK8:
                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_CD
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK9

                    ; ok same lenght
                    ld hl, CMD_CD
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK9
                    
                    ; dispatch
                    call CDCLI
                    
                    jp MAIN_END

;call CWDNCLI
MAIN_CHK9:
                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_CWD
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK10

                    ; ok same lenght
                    ld hl, CMD_CWD
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK10
                    
                    ; dispatch
                    call CWDNCLI
                    
                    jp MAIN_END


MAIN_CHK10:
                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_EXIT
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK11

                    ; ok same lenght
                    ld hl, CMD_EXIT
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK11
                    
                    ; dispatch
                    jp MAIN_RETURN

;call RUNCLI
MAIN_CHK11:

                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_RUN
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK12

                    ; ok same lenght
                    ld hl, CMD_RUN
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK12

                    ; check len of FILE_NAME
                    ld hl, FILE_NAME
                    call STRLEN

                    ;push af
                    ;call SHOWHEXBYTECR
                    ;pop af

                    cp 0x04
                    jr nz, MAIN_CHK11_ORG

                    ;ld a, '4'
                    ;call OUTCHAR

                    ; it have 4 chars
                    ; FILE_NAME to numeric 
                    ; bin at FILE_START
                    call FNAME2WORD

                    ; now prepare the copy of
                    ; TMP_WORD to FILE_START
                    ld hl, TMP_WORD

                    jr MAIN_CHK11_RUN

MAIN_CHK11_ORG:
                    ;ld a, 'D'
                    ;call OUTCHAR

                    ; it does not have the required
                    ; number of chars (4), prepare 
                    ; copy of CLI_ORG to FILE_START
                    ld hl, CLI_ORG

MAIN_CHK11_RUN:
                    ; continue the copy
                    ; set destination
                    ld de, FILE_START

                    ld a, (hl)
                    ld (de), a
                    inc hl
                    inc de
                    ld a, (hl)
                    ld (de), a

                    ; dispatch
                    call RUNCLI

                    jp MAIN_END


;call SDIFRESETCLI
MAIN_CHK12:
                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_RESET
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK13

                    ; ok same lenght
                    ld hl, CMD_RESET
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK13
                    
                    ; dispatch
                    call SDIFRESETCLI
                                        
                    jp MAIN_END

;call GETSDIFSCLI
MAIN_CHK13:
                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_SDIFS
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK14

                    ; ok same lenght
                    ld hl, CMD_SDIFS
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK14
                    
                    ; dispatch
                    call GETSDIFSCLI
                                        
                    jp MAIN_END

;call FDELCLI
MAIN_CHK14:
                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_DEL
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK15

                    ; ok same lenght
                    ld hl, CMD_DEL
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK15

                    ; dispatch
                    call FDELCLI

                    jp MAIN_END

;call FOPENCLI
MAIN_CHK15:
                IF  DEBUG

                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_FOPEN
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK16

                    ; ok same lenght
                    ld hl, CMD_FOPEN
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK16

                    ; dispatch
                    call FOPENCLI

                    jp MAIN_END

                ENDIF

;call FCLOSECLI
MAIN_CHK16:
                IF  DEBUG

                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_FCLOSE
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK17

                    ; ok same lenght
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

                ENDIF

;call FWRITECLI
MAIN_CHK17:
                IF  DEBUG

                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_FWRITE
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK18

                    ; ok same lenght
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

                ENDIF

;class FREADCLI
MAIN_CHK18:
                IF  DEBUG

                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_FREAD
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK19

                    ; ok same lenght
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

                ENDIF

;call FTELLCLI
MAIN_CHK19:
                IF  DEBUG

                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_FGETPOS
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK20

                    ; ok same lenght
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

                ENDIF

;call FSEEKSETCLI
MAIN_CHK20:
                IF  DEBUG

                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_FSEEKSET
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK21

                    ; ok same lenght
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

                ENDIF

;call FSEEKCURCLI
MAIN_CHK21:
                IF  DEBUG

                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_FSEEKCUR
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK22

                    ; ok same lenght
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

                ENDIF

;call FSEEKENDCLI
MAIN_CHK22:
                IF  DEBUG

                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_FSEEKEND
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK23

                    ; ok same lenght
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

                ENDIF

;call FREWINDCLI
MAIN_CHK23:
                IF  DEBUG

                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_FREWIND
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK24

                    ; ok same lenght
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

                ENDIF


;call FPEEKCLI
MAIN_CHK24:
                IF  DEBUG

                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_FPEEK
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK25

                    ; ok same lenght
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

                ENDIF

;call FWRITEBCLI
MAIN_CHK25:
                IF  DEBUG

                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_FWRITEB
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK26

                    ; ok same lenght
                    ld hl, CMD_FWRITEB
                    ld de, FILE_CMD

                    call STRCMP
                    jr nz, MAIN_CHK26

                    ; prepare dispatch
                    ; FILE_NAME to numeric 
                    ; bin at FILE_HDL
                    call FNAME2FHDL

                    ; debug message
                    ; call api: print str
                    ;ld   de,CMD_FWRITEB
                    ;ld   c,$06
                    ;rst  $30

                    ; output nl & cr
                    ;ld a, '\n'
                    ;call OUTCHAR
                    ;ld a, '\r'
                    ;call OUTCHAR  

                    ; dispatch
                    call FWRITEBCLI

                    jp MAIN_END

                ENDIF

;call FCATCLI
MAIN_CHK26:
                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_FCAT
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK27

                    ; ok same lenght
                    ld hl, CMD_FCAT
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK27

                    ; dispatch
                    call FCATCLI

                    jp MAIN_END

;call FREADBCLI
MAIN_CHK27:
                IF  DEBUG

                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_FREADB
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK28

                    ; ok same lenght
                    ld hl, CMD_FREADB
                    ld de, FILE_CMD

                    call STRCMP
                    jr nz, MAIN_CHK28

                    ; prepare dispatch
                    ; FILE_NAME to numeric 
                    ; bin at FILE_HDL
                    call FNAME2FHDL

                    ; debug message
                    ; call api: print str
                    ;ld   de,CMD_FWRITEB
                    ;ld   c,$06
                    ;rst  $30

                    ; output nl & cr
                    ;ld a, '\n'
                    ;call OUTCHAR
                    ;ld a, '\r'
                    ;call OUTCHAR  

                    ; dispatch
                    call FREADBCLI

                    jp MAIN_END

                ENDIF


;call FTRUNCATECLI
MAIN_CHK28:
                IF  DEBUG

                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_FTRUNCATE
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK29

                    ; ok same lenght
                    ld hl, CMD_FTRUNCATE
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK29

                    ; prepare dispatch
                    ; FILE_NAME to numeric 
                    ; bin at FILE_HDL
                    call FNAME2FHDL

                    ; dispatch
                    call FTRUNCATECLI

                    jp MAIN_END

                ENDIF

;call LSOFCLI
MAIN_CHK29:
                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_LSOF
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK30

                    ; ok same lenght
                    ld hl, CMD_LSOF
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK30
                    
                    ; dispatch
                    call LSOFCLI
                                        
                    jp MAIN_END

;call FGETSIZECLI
MAIN_CHK30:
                IF  DEBUG
                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_FGETSIZE
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK31

                    ; ok same lenght
                    ld hl, CMD_FGETSIZE
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK31

                    ; prepare dispatch
                    ; FILE_NAME to numeric 
                    ; bin at FILE_HDL
                    call FNAME2FHDL

                    ; dispatch
                    call FGETSIZECLI

                    jp MAIN_END

                ENDIF

;call FGETNAMECLI
MAIN_CHK31:
                IF  DEBUG

                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_FGETNAME
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK32

                    ; ok same lenght
                    ld hl, CMD_FGETNAME
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK32

                    ; prepare dispatch
                    ; FILE_NAME to numeric 
                    ; bin at FILE_HDL
                    call FNAME2FHDL

                    ; dispatch
                    call FGETNAMECLI

                    jp MAIN_END

                ENDIF

; call FSAVECLI
MAIN_CHK32:
                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_SAVE
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK33

                    ; ok same lenght
                    ld hl, CMD_SAVE
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK33
                    
                    ; dispatch
                    call FSAVECLI

                    jp MAIN_END

;call FDSPACECLI
MAIN_CHK33:
                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_FDSPACE
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK34

                    ; ok same lenght
                    ld hl, CMD_FDSPACE
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK34

                    ; dispatch
                    call FDSPACECLI

                    jp MAIN_END

;call TDSPACECLI
MAIN_CHK34:
                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_TDSPACE
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK35

                    ; ok same lenght
                    ld hl, CMD_TDSPACE
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK35

                    ; dispatch
                    call TDSPACECLI

                    jp MAIN_END

;SETORGCLI
MAIN_CHK35:
                    ; test string lenghts
                    ; get 1st len
                    ld hl, CMD_SETORG
                    call STRLEN
                    ; store len in register e
                    ld e, a
                    ; get 2nd len
                    ld hl, FILE_CMD
                    call STRLEN
                    ; compare it with len
                    ; in register register e
                    cp e
                    jr nz, MAIN_CHK36

                    ; ok same lenght
                    ld hl, CMD_SETORG
                    ld de, FILE_CMD
                    
                    call STRCMP
                    jr nz, MAIN_CHK36

                    ; prepare address
                    ; to set for org
                    call FNAME2WORD

                    ; copy it to memory
                    ; variable CLI_ORG
                    ld hl, TMP_WORD
                    ld de, CLI_ORG

                    ld a, (hl)
                    ld (de), a

                    inc hl
                    inc de

                    ld a, (hl)
                    ld (de), a

                    ; dispatch
                    ;call SETORGCLI

                    ; 
                    ; ok message
                    ; 
                    ld   de,STR_OK
                    ld   C,$06
                    rst   $30

                    jp MAIN_END

;
MAIN_CHK36:
                    ;
                    ; try to run cmd.com
                    ; 
                    
                    ; dispatch
                    call COMEXECLI

MAIN_END:
                    jp MAIN_LOOP

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
; main helper - FILE_NAME to Word (2 byes)
;
;--------------------------------------------------------
FNAME2WORD:
                    ; convert the FILE_NAME field
                    ; to numeric bin at FILE_HDL
                    push hl
                    push de
                    ;
                    ld hl,FILE_NAME
                    call CONVERTTOUPPER

                    ; MSB first (not little endian)
                    call CLI_HEX2TBIN1
                    ld de, TMP_WORD
                    ld (de), a

                    ; LSB second
                    call CLI_HEX2TBIN1
                    ld de, TMP_WORD
                    inc de
                    ld (de), a                   
                    ;
                    pop de
                    pop hl

                    ret

;--------------------------------------------------------
;
; main helper - remove extra spaces in command line
;
;--------------------------------------------------------
; Rotina para remover espaços consecutivos numa string
; Endereço do primeiro caractere está em HL

DELEXSRTSPC:
    push hl                     ; Salva HL no stack
    pop de                      ; Recupera HL em DE
    ld a, (hl)                  ; Carrega o primeiro caractere em A
    cp 0                        ; Verifica se é o fim da string (null terminator)
    jp z, DESSPC_DONE           ; Se for o fim da string, termina

DESSPC_LOOP:
    ld a, (hl)                  ; Carrega o próximo caractere em A
    inc hl                      ; Avança HL para o próximo caractere
    cp ' '                      ; Compara A com o caractere de espaço
    jr nz, DESSPC_CPYCHAR        ; Se não for espaço, copia o caractere

    ; Encontrou um espaço, mantém um espaço e verifica os próximos caracteres
    ld (de), a         ; Mantém um espaço na posição atual de DE
    inc de             ; Avança o ponteiro de escrita em DE

    ; Encontrou um espaço, verificar se o próximo também é espaço
DESSPC_SKIPSPC:
    ld a, (hl)                  ; Carrega o próximo caractere em A
    inc hl                      ; Avança HL para o próximo caractere
    cp 0                        ; Verifica se é o fim da string
    jp z, DESSPC_DONE                  ; Se for o fim da string, termina
    cp ' '                      ; Compara A com o caractere de espaço
    jr z, DESSPC_SKIPSPC        ; Se for espaço, ignora e avança para o próximo caractere

DESSPC_CPYCHAR:
    ld (de), a                  ; Copia o caractere para a posição atual de DE
    inc de                      ; Avança o ponteiro de escrita em DE
    cp 0                        ; Verifica se é o fim da string (null terminator)
    jr nz, DESSPC_LOOP          ; Se não for o fim, continua no loop principal

DESSPC_DONE:
    ld (de), a                  ; Escreve o null terminator no final da string
    ret                         ; Retorna da rotina

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
; Run already loaded program
;
;--------------------------------------------------------
;--------------------------------------------------------
RUNCLI:
                    ;
                    ; entry point from cli
                    ;
                    call RUNSTART

                    ret

;--------------------------------------------------------
;--------------------------------------------------------                    

RUNSTART:
                    ; check if it is
                    ; a valid number
                    ; cannot be 0101
                    ld hl, FILE_START
                    ld a,(hl)
                    inc hl
                    ld e,(hl)

                    ; check if a = e
                    cp e
                    jr nz, RUNSTART_OK1

                    ; check if they are 01
                    cp 0x01
                    jr nz, RUNSTART_OK1  

                    ; not ok show error msg
                    ; call api: print str
                    ld   de, STR_ARG_ERROR
                    ld   c,$06
                    rst  $30

                    ret                  

RUNSTART_OK1:
                    ;
                    ; its a valid hex (is not 0101)
                    ; try to run the program
                    ;
                    
                    ld de, FILE_START
                    ld a, (de);
                    ld h, a
                    inc de
                    ld a,(de);
                    ld l, a

                    ; call it
                    jp (hl)

                    ;
                    ; end
                    ;

                    ld a, 0x00
                    ret

;--------------------------------------------------------
;
; try to run command from a file on root directory of SD
;
;--------------------------------------------------------
;--------------------------------------------------------
COMEXECLI:
                    ;
                    ; entry point from cli
                    ;
                    call COMEXE

                    ret

;--------------------------------------------------------
;--------------------------------------------------------                    

COMEXE:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,COMEXE_OK1

; just info
COMEXE_FAIL1:
                    ret

COMEXE_OK1:
                    ;
                    ; make a copy of FILE_CMD
                    ; to FILE_NAME
                    ;
                    ld hl, FILE_CMD
                    ld de, FILE_NAME                      
                    call STRCPY

                    ;
                    ; try fname.com
                    ; add .com to string
                    ;
                    ld hl, STR_COM
                    ld de, FILE_NAME
                    call STRCAT

                    ;
                    ; check if com file exists
                    ;
                    call FEXISTFN

                    ; read memory variable
                    ; with output of FEXISTFN
                    ld hl, OUT_BYTE
                    ld a, (hl)

                    ; check if exists
                    ; and is a file
                    cp 0x01              
                    jr z, COMEXE_OK2
                    
                    ;
                    ; it is not a .com file
                    ; lets try an exe file  
                    ;

                    ; make a copy of FILE_CMD
                    ; to FILE_NAME
                    ld hl, FILE_CMD
                    ld de, FILE_NAME                      
                    call STRCPY

                    ; add .exe to string
                    ld hl, STR_EXE
                    ld de, FILE_NAME
                    call STRCAT

                    ;
                    ; check if com file exists
                    ;
                    call FEXISTFN

                    ; read memory variable
                    ; with output of FEXISTFN
                    ld hl, OUT_BYTE
                    ld a, (hl)

                    ; check if exists
                    ; and is a file
                    cp 0x01              
                    jr z, COMEXE_OK2

                    ;
                    ; it is not a .com file
                    ; nor a .ex file 
                    ;
                    jr COMEXE_NOTFOUND

COMEXE_OK2:
                    ;
                    ; is .com or .exe file
                    ;        

                    ;
                    ; prepare arguments
                    ; to call LOAD
                    ; 

                    ; we have the FILE_NAME
                    ; copy variable CLI_ORG
                    ; to FILE_START
                    ld hl, CLI_ORG
                    ld de, FILE_START

                    ld a, (hl)
                    ld (de), a

                    inc hl
                    inc de

                    ld a, (hl)
                    ld (de), a

                    ; load the file program
                    call FLOADFN

                    ; check for operation result
                    ; return erro if not ok (0x00)
                    cp 0x00
                    jr z, COMEXE_OK

                    ; it have and error
                    ; return
                    ret

COMEXE_NOTFOUND:
                    ;
                    ; show command not found
                    ; message and return
                    ; 
                    ld   de,STR_CMD_NOTFOUND
                    ld   C,$06
                    rst   $30

                    ; output nl & cr
                    ld a, '\n'
                    call OUTCHAR
                    ld a, '\r'
                    call OUTCHAR                    

                    ; not an error
                    ld a, 0x00

                    ret
COMEXE_OK:
                    ;
                    ; run program
                    ;
                    
                    ld de, CLI_ORG
                    ld a, (de);
                    ld h, a
                    inc de
                    ld a,(de);
                    ld l, a

                    ;call (hl)

                    jp (hl)

                    ;
                    ; end
                    ;

                    ld a, 0x00
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
; Start List files in a directory on SD proccess
;
;--------------------------------------------------------
SLISTAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    
SLISTFN:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,SLISTFN_OK1

; just info
SLISTFN_FAIL1:
                    ret

SLISTFN_OK1:
                    
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
                    jr   z,SLISTFN_OK2

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x02
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                    

SLISTFN_OK2:
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
                    ld   de, 100
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get status
                    in   a,(SDCRS)   
                    ; is list dir state ?
                    cp   SDCSIDL
                    jr   z, SLISTFN_OK
                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x03
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret
       
SLISTFN_OK:
                    ;
                    ; directory ready to list
                    ;
                    ; need to get names
                    ; file by file (or directory)
                    ; with another routine

                    ld a, 0x00
                    ret

;--------------------------------------------------------
;
; List each file/dir name on directory (need call slist first) (no cli)
;
;--------------------------------------------------------
CLISTAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    
CLISTGI:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,CLISTGI_OK1

; just info
CLISTGI_FAIL1:
                    ret

CLISTGI_OK1:
                    
                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld  de, 1
                    ld  c, $0a
                    rst $30
                    pop hl

                    ; start get an item from directory list
                    ; load cmd code in a, see equs
                    ld   a,SDCMDCLIST   
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
                    ; if status is not ok exit
                    cp   SDCSDIR
                    jr   z,CLISTGI_OK2

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x02
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                    

CLISTGI_OK2:
                    ; read the filename
                    ; chars to buffer

                    ; set hl register to lsof 
                    ; buffer start in memory
                    ld hl, OUTBUFFER

CLISTGI_LOOP:
                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get data
                    in   a,(SDCRD)

                    ; dont store the new line
                    cp '\n'
                    jr z, CLISTGI_LOOPJ

                    ; store data in memory
                    ld (hl), a

                    ; increment and
                    ; set terminator
                    inc hl

CLISTGI_LOOPJ:                    
                    ld (hl), 0x00

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
                    cp   SDCSDIR
                    jr   z, CLISTGI_LOOP

                    ; 
                    ; we are out of loop
                    ; we expect idle status
                    ;

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
                    jr   z, CLISTGI_OK

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x03
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret

CLISTGI_OK:
                    ;
                    ; directory ready to list
                    ;
                    ; need to get names
                    ; file by file (or directory)
                    ; with another routine

                    ld a, 0x00
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
                    ld   a,SDCMDRWEND ;0x0b   
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

                    call SHOWHEXBYTECR
                    
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

                    call SHOWHEXBYTECR
                     
                    ; and ok end message
                    ; using scm api
                    ld   de,STR_EXISTOK
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

IF DEBUG

FOPENCLI:
                    ;
                    ; entry point from cli
                    ;
                    call FOPENFN

                    ; check for operation result
                    cp 0x00
                    jr z, FOPENCLI_OK

                    ; display error code

                    call SHOWHEXBYTECR

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

                    call SHOWHEXBYTECR

                    ; and ok end message
                    ; using scm api
                    ld   de,STR_OK
                    ld   C,$06
                    rst   $30
                    ret

ENDIF

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
                    ;call SHOWHEXBYTECR
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

                    ; file handle id must
                    ; be greater than zero
                    cp 0x00
                    jr nz, FOPENFN_OK5

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x05
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret 
FOPENFN_OK5:
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
                    ld a, 0x06
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

IF DEBUG

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

ENDIF

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
                    ;call SHOWHEXBYTECR
                    ;pop af

                    out (SDCWD),a

                    pop  af
                    pop  hl

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

                    ; wait 10 ms before exit
                    ; wait for sync on close
                    push hl
                    ld   de, 10
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ld a, 0x00
                    ret

;--------------------------------------------------------
;
; File write one byte - fwrite (int *ofhld, int b)
;
;--------------------------------------------------------
;--------------------------------------------------------

IF DEBUG

FWRITECLI:
                    ;
                    ; entry point from cli
                    ;
                    call FWRITEFH

                    ; check for operation result
                    cp 0x00
                    jr z, FWRITECLI_OK

                    ; display error code
                    call SHOWHEXBYTECR

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

                    call SHOWHEXBYTECR

                    ; and ok end message
                    ; using scm api
                    ld   de,STR_OK
                    ld   C,$06
                    rst   $30
                    ret

ENDIF

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
                    ;call SHOWHEXBYTECR
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
                    ;call SHOWHEXBYTECR
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

                    ; prepare time wait for
                    ; sdcard to write data
                    ld b, 0xff

FWRITEWIDLE:
                    ; check for wait
                    ; for idle timeout
                    ld a, b
                    cp 0x00
                    jr z, FWRITEIDLETOUT

                    ; wait many ms before any
                    ; in or out to SD card
                    ; with sync we need
                    ; at least 20ms
                    push bc
                    push hl
                    ld   de, 10
                    ld   c, $0a
                    rst  $30
                    pop  hl
                    pop bc
                    
                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSIDL
                    jr   z, FWRITEFH_OK
                    
                    ; continue waiting
                    ; for idle, until
                    ; b == 0, or status idle
                    dec b
                    jr FWRITEWIDLE

FWRITEIDLETOUT: 
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
; write bytes to file fwriteb (int *ofhld, int *address, int *nbytes )
;
;--------------------------------------------------------
;--------------------------------------------------------

IF DEBUG

FWRITEBCLI:
                    ;
                    ; entry point from cli
                    ;
                    call FWRITEBFH

                    ; check for operation result
                    cp 0x00
                    jr z, FWRITEBCLI_OK

                    ; display error code
                    call SHOWHEXBYTECR

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                                 

FWRITEBCLI_OK:
                    ; read memory variable
                    ; hold file handle
                    ld hl, NUM_BYTES
                    ; read MSB
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

                    ; read LSB
                    pop hl
                    dec hl         
                    ld a, (hl)

                    call SHOWHEXBYTECR

                    ; display ok end message
                    ; using scm api
                    ld   de,STR_OK
                    ld   C,$06
                    rst   $30
                    ret

ENDIF

;--------------------------------------------------------
;--------------------------------------------------------
FWRITEBAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    
FWRITEBFH:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,FWRITEBFH_OK1 

; just info
FWRITEBFH_FAIL1:
                    ret

FWRITEBFH_OK1:
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
                    ld   a,SDCMDFWRITEB   
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
                    cp   SDCSFWBHDL
                    jr   z,FWRITEBFH_OK2
                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x02
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                      
                    
FWRITEBFH_OK2:
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
                    ;call SHOWHEXBYTECR
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
                    cp   SDCSFWRITEB
                    jr   z, FWRITEBWD_OK  

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x03
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                 

FWRITEBWD_OK:
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
                    
FWRITEBWDLOOP:      
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

                    ; check if media
                    ; gives error
                    push de
                    push bc
                    push hl
                    push af

                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSFWRITEB
                    jr   nz, FWRITEBWDERR

                    pop af
                    pop hl
                    pop bc
                    pop de

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
                    jr nz,FWRITEBWDLOOP

                    jr FWRITEBWDEND

FWRITEBWDERR:
                    ; there is an error reading
                    ; maybe media is out of space

                    ;restore registers
                    pop af
                    pop hl
                    pop bc
                    pop de

                    ; dont need signal end of write bytes
                    jr FWRITEBWDEND_OK1

FWRITEBWDEND:
                    ; wait 1 ms before any
                    ; in or out to SD card
                    push de
                    push bc
                    push hl
                    ld de, 1
                    ld c, $0a
                    rst $30
                    pop hl
                    pop bc
                    pop de

                    ; signal end of write bytes
                    ; load cmd code in a, see equs
                    ld   a,SDCMDRWEND ;0x0b   
                    out  (SDCWC),a   

FWRITEBWDEND_OK1: 
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
                    cp   SDCSFWBSTAT   
                    jr   z,FWRITEBWDRES   

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x04
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret 

FWRITEBWDRES:

                    ; read operation result

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get data (1st byte)
                    in   a,(SDCRD)   
                    
                    ; store data in memory
                    ; LSB first 
                    ld hl, NUM_BYTES
                    ;inc hl
                    ld (hl), a

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl
                    
                    ; get data (2nd byte)
                    in   a,(SDCRD)

                    ; store data in memory
                    ; MSB second
                    inc hl
                    ld (hl), a

                    ; prepare time wait for
                    ; sdcard to write data
                    ld b, 0xff

FWRITEBWIDLE:
                    ; check for wait
                    ; for idle timeout
                    ld a, b
                    cp 0x00
                    jr z, FWRITEBIDLETOUT
                    
                    ; wait many ms before any
                    ; in or out to SD card
                    ; with sync we need
                    ; at least 40ms
                    push bc
                    push hl
                    ld   de, 10
                    ld   c, $0a
                    rst  $30
                    pop  hl
                    pop bc

                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSIDL
                    jr   z, FWRITEBEND_OK

                    ; continue waiting
                    ; for idle, until
                    ; b == 0, or status idle
                    dec b
                    jr FWRITEBWIDLE

FWRITEBIDLETOUT:                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x05
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret 

FWRITEBEND_OK:                    
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

IF DEBUG

FREADCLI:
                    ;
                    ; entry point from cli
                    ;
                    call FREADFH

                    ; check for operation result
                    cp 0x00
                    jr z, FREADCLI_OK

                    ; display error code
                    call SHOWHEXBYTECR

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                 

FREADCLI_OK:

                    ;
                    ; display readed char
                    ;

                    ; read memory variable
                    ld hl, OUT_BYTE
                    ld a, (hl)

                    call SHOWHEXBYTECR

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

                    ld a, ' '
                    call OUTCHAR 

                    ; and ok end message
                    ; using scm api
                    ld   de,STR_OK
                    ld   C,$06
                    rst   $30
                    
                    ret

ENDIF

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
                    ;call SHOWHEXBYTECR
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
; Read bytes from file  freadb (int *ofhld, int *address, int *nbytes )
;
;--------------------------------------------------------
;--------------------------------------------------------

IF DEBUG

FREADBCLI:
                    ;
                    ; entry point from cli
                    ;
                    call FREADBFH

                    ; check for operation result
                    cp 0x00
                    jr z, FREADBCLI_OK

                    ; display error code
                    call SHOWHEXBYTECR

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                                 

FREADBCLI_OK:
                    ; read memory variable
                    ; hold file handle
                    ld hl, NUM_BYTES
                    ; read MSB
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

                    ; read LSB
                    pop hl
                    dec hl         
                    ld a, (hl)

                    call SHOWHEXBYTECR

                    ; display ok end message
                    ; using scm api
                    ld   de,STR_OK
                    ld   C,$06
                    rst   $30
                    ret

ENDIF

;--------------------------------------------------------
;--------------------------------------------------------
FREADBAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    
FREADBFH:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,FREADBFH_OK1 

; just info
FREADBFH_FAIL1:
                    ret

FREADBFH_OK1:
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
                    ld   a,SDCMDFREADB   
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
                    cp   SDCSFRBHDL
                    jr   z,FREADBFH_OK2
                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x02
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                      
                    
FREADBFH_OK2:
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
                    ;call SHOWHEXBYTECR
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
                    cp   SDCSFREADB
                    jr   z, FREADBWD_OK  

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x03
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                 

FREADBWD_OK:
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
                                        
                    ld   c,SDCRD 
                    
FREADBRDLOOP:      
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

                    ; check if media
                    ; gives error
                    push de
                    push bc
                    push hl
                    push af

                    ; get sdif status
                    in   a,(SDCRS)   
                    ; if status is not ok exit
                    cp   SDCSFREADB
                    jr   nz, FREADBRDERR

                    pop af
                    pop hl
                    pop bc
                    pop de

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

                    ; input one memory byte
                    ini
                    
                    ; control if its over
                    dec de
                    
                    ; check if de is zero
                    ;push a
                    ld a, d
                    or e
                    ;pop a
                    
                    ; not zero
                    jr nz,FREADBRDLOOP

                    jr FREADBRDEND

FREADBRDERR:
                    ; there is an error reading
                    ; maybe end of file is reached
                    ; convert to hex

                    ;restore registers
                    pop af
                    pop hl
                    pop bc
                    pop de

                    ; dont need signal end of write bytes
                    jr FREADBRDEND_OK1

FREADBRDEND:
                    ; wait 1 ms before any
                    ; in or out to SD card
                    push de
                    push bc
                    push hl
                    ld de, 1
                    ld c, $0a
                    rst $30
                    pop hl
                    pop bc
                    pop de

                    ; signal end of write bytes
                    ; load cmd code in a, see equs
                    ld   a,SDCMDRWEND ;0x0b   
                    out  (SDCWC),a   

FREADBRDEND_OK1: 
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
                    cp   SDCSFRBSTAT   
                    jr   z,FREADBRDRES   

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x04
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret 

FREADBRDRES:

                    ; read operation result

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl

                    ; get data (1st byte)
                    in   a,(SDCRD)   
                    
                    ; store data in memory 
                    ld hl, NUM_BYTES
                    ld (hl), a

                    ; wait 1 ms before any
                    ; in or out to SD card
                    push hl
                    ld   de, 1
                    ld   c, $0a
                    rst  $30
                    pop  hl
                    
                    ; get data (2nd byte)
                    in   a,(SDCRD)

                    ; store data in memory 
                    inc hl
                    ld (hl), a

                    ; wait many ms before any
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
                    jr   z, FREADBEND_OK
                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x05
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret 

FREADBEND_OK:                    
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

IF DEBUG

FPEEKCLI:
                    ;
                    ; entry point from cli
                    ;
                    call FPEEKFH

                    ; check for operation result
                    cp 0x00
                    jr z, FPEEKCLI_OK

                    ; display error code
                    call SHOWHEXBYTECR

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
                    
                    call SHOWHEXBYTECR

                    ; and ok end message
                    ; using scm api
                    ld   de,STR_OK
                    ld   C,$06
                    rst   $30
                    ret

ENDIF

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
                    ;call SHOWHEXBYTECR
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

IF DEBUG

FTELLCLI:
                    ;
                    ; entry point from cli
                    ;
                    call FTELLFH

                    ; check for operation result
                    cp 0x00
                    jr z, FTELLCLI_OK

                    ; display error code
                    call SHOWHEXBYTECR

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

ENDIF

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
                    ;call SHOWHEXBYTECR
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

IF DEBUG

FSEEKSETCLI:
                    ;
                    ; entry point from cli
                    ;
                    call FSEEKSETFH

                    ; check for operation result
                    cp 0x00
                    jr z, FSEEKSETCLI_OK

                    ; display error code
                    call SHOWHEXBYTECR

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

                    call SHOWHEXBYTECR

                    ; and ok end message
                    ; using scm api
                    ld   de,STR_OK
                    ld   C,$06
                    rst   $30
                    ret

ENDIF

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
                    ;call SHOWHEXBYTECR
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
                    ;call SHOWHEXBYTECR
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
                    ;call SHOWHEXBYTECR
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

IF DEBUG

FSEEKCURCLI:
                    ;
                    ; entry point from cli
                    ;
                    call FSEEKCURFH

                    ; check for operation result
                    cp 0x00
                    jr z, FSEEKCURCLI_OK

                    ; display error code
                    call SHOWHEXBYTECR

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

                    call SHOWHEXBYTECR

                    ; and ok end message
                    ; using scm api
                    ld   de,STR_OK
                    ld   C,$06
                    rst   $30
                    ret

ENDIF

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
                    ;call SHOWHEXBYTECR
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
                    ;call SHOWHEXBYTECR
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
                    ;call SHOWHEXBYTECR
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

IF DEBUG

FSEEKENDCLI:
                    ;
                    ; entry point from cli
                    ;
                    call FSEEKENDFH

                    ; check for operation result
                    cp 0x00
                    jr z, FSEEKENDCLI_OK

                    ; display error code
                    call SHOWHEXBYTECR

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

                    call SHOWHEXBYTECR

                    ; and ok end message
                    ; using scm api
                    ld   de,STR_OK
                    ld   C,$06
                    rst   $30
                    ret

ENDIF

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
                    ;call SHOWHEXBYTECR
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
                    ;call SHOWHEXBYTECR
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
                    ;call SHOWHEXBYTECR
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

IF DEBUG

FREWINDCLI:
                    ;
                    ; entry point from cli
                    ;
                    call FREWINDFH

                    ; check for operation result
                    cp 0x00
                    jr z, FREWINDCLI_OK

                    ; display error code
                    call SHOWHEXBYTECR

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

ENDIF

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
                    ;call SHOWHEXBYTECR
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
; File position set - seekend (int *ofhld, int32 p)
;
;--------------------------------------------------------
;--------------------------------------------------------

IF DEBUG

FTRUNCATECLI:
                    ;
                    ; entry point from cli
                    ;
                    call FTRUNCATEFH

                    ; check for operation result
                    cp 0x00
                    jr z, FTRUNCATECLI_OK

                    ; display error code
                    call SHOWHEXBYTECR

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                 

FTRUNCATECLI_OK:
                    ;
                    ; display result
                    ;

                    ; read memory variable
                    ld hl, OUT_BYTE1
                    ld a, (hl)

                    call SHOWHEXBYTECR

                    ; and ok end message
                    ; using scm api
                    ld   de,STR_OK
                    ld   C,$06
                    rst   $30
                    ret

ENDIF

;--------------------------------------------------------
;--------------------------------------------------------
FTRUNCATEAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    
FTRUNCATEFH:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,FTRUNCATEFH_OK1 

; just info
FTRUNCATEFH_FAIL1:
                    ret

FTRUNCATEFH_OK1:
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

                    ; start truncate file
                    ; load cmd code in a, see equs
                    ld   a,SDCMDFTRUNCATE   
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
                    cp   SDCSFTRCTHDL
                    jr   z,FTRUNCATEFH_OK2

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x02
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret

FTRUNCATEFH_OK2:
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
                    ;call SHOWHEXBYTECR
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
                    cp   SDCSFTRUNCATE
                    jr   z, FTRUNCATEFH_OK3  

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x03
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                 

FTRUNCATEFH_OK3:
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
                    ;call SHOWHEXBYTECR
                    ;pop af

                    out (SDCWD),a

                    ; wait 1 ms before any
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
                    ;call SHOWHEXBYTECR
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
                    cp   SDCSFTRCTSTAT
                    jr   z, FTRUNCATEFH_OK4  

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x04
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                  

FTRUNCATEFH_OK4:
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
                    jr   z, FTRUNCATEFH_OK
                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x05
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret 

FTRUNCATEFH_OK:
                    ;
                    ; operation ok
                    ;

                    ld a, 0x00
                    ret

;--------------------------------------------------------
;
; Get file size - fgetsize (int *ofhld)
;
;--------------------------------------------------------
;--------------------------------------------------------

IF DEBUG

FGETSIZECLI:
                    ;
                    ; entry point from cli
                    ;
                    call FGETSIZEFH

                    ; check for operation result
                    cp 0x00
                    jr z, FGETSIZECLI_OK

                    ; display error code
                    call SHOWHEXBYTECR

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                 

FGETSIZECLI_OK:
                    ;
                    ; display file size
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

ENDIF

;--------------------------------------------------------
;--------------------------------------------------------
FGETSIZEAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    
FGETSIZEFH:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,FGETSIZEFH_OK1

; just info
FGETSIZEFH_FAIL1:
                    ret

FGETSIZEFH_OK1:
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

                    ; start get file size
                    ; load cmd code in a, see equs
                    ld   a,SDCMDFGETSIZE   
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
                    cp   SDCSFGSIZEHDL
                    jr   z,FGETSIZEFH_OK2

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x02
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret

FGETSIZEFH_OK2:
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
                    ;call SHOWHEXBYTECR
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
                    cp   SDCSFGSIZE
                    jr   z, FGETSIZEFH_OK3  

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x03
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                  

FGETSIZEFH_OK3:
                    ; set variable top
                    ; memory address
                    ld hl, OUT_LONG
                    inc hl
                    inc hl
                    inc hl

FGETSIZEFH_LOOP:
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
                    cp   SDCSFGSIZE
                    jr   z, FGETSIZEFH_LOOP
                    
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
                    jr   z, FGETSIZEFH_OK
                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x04
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret

FGETSIZEFH_OK:
                    ;
                    ; operation ok
                    ;

                    ld a, 0x00
                    ret

;--------------------------------------------------------
;
; Get file name - fgetname (int *ofhld)
;
;--------------------------------------------------------
;--------------------------------------------------------

IF DEBUG

FGETNAMECLI:
                    ;
                    ; entry point from cli
                    ;
                    call FGETNAMEFH

                    ; check for operation result
                    cp 0x00
                    jr z, FGETNAMECLI_OK1

                    ; display error code
                    call SHOWHEXBYTECR

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                
                    ret                 

FGETNAMECLI_OK1:
                    ;
                    ; display file name
                    ;

                    ; set base filename
                    ; chars buffer address
                    ld hl, OUTBUFFER

                    ; load byte check zero for end
                    ld a, (hl)
                    cp 0x00
                    jr z, FGETNAMECLI_OK

FGETNAMECLI_LOOP:                    
                    ; display char
                    call OUTCHAR                

                    ; next char
                    inc hl

                    ; load char check zero for end
                    ld a, (hl)
                    cp 0x00
                    jr nz, FGETNAMECLI_LOOP

                    ; is zero, filename end
                    ; we are almost done

FGETNAMECLI_OK:

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

ENDIF

;--------------------------------------------------------
;--------------------------------------------------------
FGETNAMEAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    
FGETNAMEFH:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,FGETNAMEFH_OK1

; just info
FGETNAMEFH_FAIL1:
                    ret

FGETNAMEFH_OK1:
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

                    ; start get file size
                    ; load cmd code in a, see equs
                    ld   a,SDCMDFGETNAME   
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
                    cp   SDCSFGNAMEHDL
                    jr   z,FGETNAMEFH_OK2

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x02
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret

FGETNAMEFH_OK2:
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
                    ;call SHOWHEXBYTECR
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
                    cp   SDCSFGNAME
                    jr   z, FGETNAMEFH_OK3  

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x03
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret                  

FGETNAMEFH_OK3:
                    ; read the filename
                    ; chars to buffer

                    ; set hl register to lsof 
                    ; buffer start in memory
                    ld hl, OUTBUFFER

FGETNAME_LOOP:
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
                    ld (hl), a

                    ; increment and
                    ; set terminator
                    inc hl
                    ld (hl), 0x00

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
                    cp   SDCSFGNAME
                    jr   z, FGETNAME_LOOP

                    ; 
                    ; we are out of loop
                    ; we expect idle status
                    ;

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
                    jr   z, FGETNAME_OK

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x03
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret 

FGETNAME_OK:
                    ;
                    ; operation ok
                    ;

                    ld a, 0x00
                    ret

;--------------------------------------------------------
;
; Get open files list (lsof)
;
;--------------------------------------------------------
;--------------------------------------------------------
LSOFCLI:
                    ;
                    ; entry point from cli
                    ;
                    call LSOF

                    ; check for operation result
                    cp 0x00
                    jr z, LSOFCLI_OK1

                    ; display error code
                    call SHOWHEXBYTECR

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                 

LSOFCLI_OK1:
                    ;
                    ; display result
                    ;

                    ; get handle if from
                    ; memory buffer

                    ld hl, OUTBUFFER
                    
                    ; load byte check zero for end
                    ld a, (hl)
                    cp 0x00
                    jr z, LSOFCLI_NLOOP

LSOFCLI_LOOP:                    
                    push hl

                    ; convert to hex
                    call NUM2HEX;

                    ; display hex
                    ld a, d
                    call OUTCHAR 
                    ld a, e
                    call OUTCHAR 

                    ld a, ' '
                    call OUTCHAR

                    ; next byte
                    pop hl
                    inc hl

                    ; load byte check zero for end
                    ld a, (hl)
                    cp 0x00
                    jr nz, LSOFCLI_LOOP

                    ; is zero, skip no loop
                    jr LSOFCLI_OK

LSOFCLI_NLOOP:
                    ld a, '0'
                    call OUTCHAR
                    ld a, '0'
                    call OUTCHAR

LSOFCLI_OK:
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
LSOFAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    
LSOF:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,LSOF_OK1 

; just info
LSOF_FAIL1:
                    ret

LSOF_OK1:
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

                    ; start read open file list
                    ; load cmd code in a, see equs
                    ld   a,SDCMDLSOF   
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
                    cp   SDCSLSOFRD
                    jr   z,LSOF_OK2

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x02
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret 

LSOF_OK2:
                    ; read the bytes to lsof buffer

                    ; set hl register to lsof 
                    ; buffer start in memory
                    ld hl, OUTBUFFER

LSOF_LOOP:
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
                    ld (hl), a

                    ; increment and
                    ; set terminator
                    inc hl
                    ld (hl), 0x00

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
                    cp   SDCSLSOFRD
                    jr   z, LSOF_LOOP

                    ; 
                    ; we are out of loop
                    ; we expect idle status
                    ;

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
                    jr   z, LSOF_OK

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x03
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret 
LSOF_OK:
                    ;
                    ; operation ok
                    ;

                    ld a, 0x00
                    ret

;--------------------------------------------------------
;
; Get free space in sdcard  - fdspace
;
;--------------------------------------------------------
;--------------------------------------------------------

FDSPACECLI:
                    ;
                    ; entry point from cli
                    ;
                    call FDSPACE

                    ; check for operation result
                    cp 0x00
                    jr z, FDSPACECLI_OK

                    ; display error code
                    call SHOWHEXBYTECR

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                 

FDSPACECLI_OK:
                    ;
                    ; display file size
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
FDSPACEAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    
FDSPACE:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,FDSPACE_OK1

; just info
FDSPACE_FAIL1:
                    ret

FDSPACE_OK1:
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

                    ; start get file size
                    ; load cmd code in a, see equs
                    ld   a,SDCMDFREESPACE   
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
                    cp   SDCSFREESPACE
                    jr   z,FDSPACE_OK2

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x02
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret

FDSPACE_OK2:
                    ; set variable top
                    ; memory address
                    ld hl, OUT_LONG
                    inc hl
                    inc hl
                    inc hl

FDSPACE_LOOP:
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
                    cp   SDCSFREESPACE
                    jr   z, FDSPACE_LOOP
                    
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
                    jr   z, FDSPACE_OK
                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x04
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret

FDSPACE_OK:
                    ;
                    ; operation ok
                    ;

                    ld a, 0x00
                    ret

;--------------------------------------------------------
;
; Get total space in sdcard in MB - fdspace
;
;--------------------------------------------------------
;--------------------------------------------------------

TDSPACECLI:
                    ;
                    ; entry point from cli
                    ;
                    call TDSPACE

                    ; check for operation result
                    cp 0x00
                    jr z, TDSPACECLI_OK

                    ; display error code
                    call SHOWHEXBYTECR

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                 

TDSPACECLI_OK:
                    ;
                    ; display file size
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
TDSPACEAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------                    
TDSPACE:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,TDSPACE_OK1

; just info
TDSPACE_FAIL1:
                    ret

TDSPACE_OK1:
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

                    ; start get file size
                    ; load cmd code in a, see equs
                    ld   a,SDCMDTOTALSPACE   
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
                    cp   SDCSTOTALSPACE
                    jr   z,TDSPACE_OK2

                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x02
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret

TDSPACE_OK2:
                    ; set variable top
                    ; memory address
                    ld hl, OUT_LONG
                    inc hl
                    inc hl
                    inc hl

TDSPACE_LOOP:
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
                    cp   SDCSTOTALSPACE
                    jr   z, TDSPACE_LOOP
                    
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
                    jr   z, TDSPACE_OK
                    
                    ; set error code and
                    ; return to caller
                    ;push hl
                    ld a, 0x04
                    ld hl, ERROR_CODE
                    ld (hl), a
                    ;pop hl

                    ret

TDSPACE_OK:
                    ;
                    ; operation ok
                    ;

                    ld a, 0x00
                    ret

;--------------------------------------------------------
;
; List files in a directory on SD
;
;--------------------------------------------------------
                    ;
                    ; multi operation
                    ; 1 - start list (slist)
                    ; 2 - n times read list item (clist)
                    ;
;--------------------------------------------------------
LISTCLI:     
                    ;
                    ; entry point from cli
                    ;
                    call LISTFN

                    ; check for operation result
                    cp 0x00
                    jr z, LISTCLI_OK

                    ; display error code

                    ; convert to hex
                    call NUM2HEX;

                    ; display hex
                    ld a, d
                    call OUTCHAR 
                    ld a, e
                    call OUTCHAR 

                    ; separator
                    ld a, ' '
                    call OUTCHAR 

                    ; read memory variable
                    ; operation index in multi operations
                    ld hl, TMP_BYTE2
                    ld a, (hl)

                    call SHOWHEXBYTECR

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                 

LISTCLI_OK:
                    ;
                    ; list ends ok
                    ;

                    ld a, '\n'
                    call OUTCHAR 
                    ld a, '\r'
                    call OUTCHAR

                    ; display end message
                    ; using scm api
                    ld   de,STR_DIROK
                    ld   C,$06
                    rst   $30
                    ret

;--------------------------------------------------------
;--------------------------------------------------------  
LISTFN:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,LISTFN_OK1
; just info
LISTFN_FAIL1:
                    ret

LISTFN_OK1:
                    ;
                    ; sdif status is ok to proceed
                    ;
                    ; we already have the name
                    ; of the dir we want to 
                    ; get the list of files/dirs
                    ;

                    ;
                    ; call slist (start list process)
                    ;

                    ; signal that we are
                    ; entering slist fname
                    ld hl, TMP_BYTE2  
                    ld (hl), 0x01

                    ; call slist (not entering by api)
                    call SLISTFN

                    ; return if we have an error
                    ; error is when a != 0 
                    cp 0x00
                    ret nz

; just info
LISTFN_OK2:
                    ; signal that we are
                    ; entering clist to get
                    ; a directory item
                    ld hl, TMP_BYTE2  
                    ld (hl), 0x02

LISTFN_LOOP:
                    ; call cist (not entering by api)
                    call CLISTGI

                    ; check if its null
                    ld hl, OUTBUFFER
                    ld a, (hl)
                    cp 0x00
                    jr z, LISTFN_OK

                    ; display file/dir name
                    ;push hl
                    ld de, OUTBUFFER
                    ld   C,$06
                    rst   $30
                    ;pop hl

                    ; we have an \n terminator
                    ; need to put the \r
                    ld a, '\n'
                    call OUTCHAR
                    ld a, '\r'
                    call OUTCHAR

                    ; do until we have itens
                    ; to list, OUTBUFFER[0] != 0
                    jr LISTFN_LOOP

LISTFN_OK:
                    ;
                    ; directory list done
                    ;
                    ; need to get names
                    ; file by file (or directory)
                    ; with another routine

                    ld a, 0x00
                    ret

;--------------------------------------------------------
;
; File cat - cat (int *strfname)
;
;--------------------------------------------------------
                    ;
                    ; multi operation
                    ; 1 - file open
                    ; 2 - file read (n times)
                    ; 3 - file close
                    ;
;--------------------------------------------------------
FCATCLI:     
                    ;
                    ; entry point from cli
                    ;
                    call FCATFN

                    ; check for operation result
                    cp 0x00
                    jr z, FCATCLI_OK

                    ; display error code

                    ; convert to hex
                    call NUM2HEX;

                    ; display hex
                    ld a, d
                    call OUTCHAR 
                    ld a, e
                    call OUTCHAR 

                    ; separator
                    ld a, ' '
                    call OUTCHAR 

                    ; read memory variable
                    ; operation index in multi operations
                    ld hl, TMP_BYTE2
                    ld a, (hl)

                    call SHOWHEXBYTECR

                    ; display error end message
                    ; using scm api
                    ld   de,STR_SDSTATUS_BAD
                    ld   C,$06
                    rst   $30
                    ret                 

FCATCLI_OK:
                    ; read memory variable
                    ; hold file handle
                    ;ld hl, TMP_BYTE
                    ;ld a, (hl)

                    ; convert to hex
                    ;call NUM2HEX;

                    ; display hex
                    ;ld a, d
                    ;call OUTCHAR 
                    ;ld a, e
                    ;call OUTCHAR 

                    ld a, '\n'
                    call OUTCHAR 
                    ld a, '\r'
                    call OUTCHAR

                    ld a, '\n'
                    call OUTCHAR 
                    ld a, '\r'
                    call OUTCHAR
                                        ;
                    ; display end message
                    ; using scm api

                    ld   de,STR_OK
                    ld   C,$06
                    rst   $30
                    ret

;--------------------------------------------------------
;--------------------------------------------------------
FCATAPI:
                    ;
                    ; entry point from api
                    ;

;--------------------------------------------------------
;--------------------------------------------------------  
FCATFN:
                    ; check idle status                    
                    call SDCIDLECHK
                    jr   z,FCATFN_OK1
; just info
FCATFN_FAIL1:
                    ret

FCATFN_OK1:
                    ;
                    ; sdif status is ok to proceed
                    ;
                    ; prepare variables to call
                    ; fopen routine
                    ;

                    ; reset the file handle id
                    ; stored on memory
                    ld hl, TMP_BYTE   
                    ld (hl), 0x00

                    ; we already have the
                    ; the filename, but
                    ; the open mode is
                    ; allways 0000                 
                    ld hl, FILE_START   
                    ld (hl), 0x00
                    inc hl                   
                    ld (hl), 0x00
                    
                    ;
                    ; open file
                    ;

                    ; signal that we are
                    ; entering fopen fname omode
                    ld hl, TMP_BYTE2  
                    ld (hl), 0x01

                    ; call fopen (not entering by api)
                    call FOPENFN

                    ; return if we have an error
                    ; error is when a != 0 
                    cp 0x00
                    ret nz

; just info
FCATFN_OK2:
                    ; store file handle in memory
                    ld hl, OUT_BYTE
                    ld a, (hl)
                    ld hl, TMP_BYTE
                    ld (hl), a

                    ; read byte from file until it ends
                    ; and display received char
                    ; using fread (handle)

                    ;
                    ; prepare fread
                    ;

                    ; signal that we are
                    ; entering fread handle_id
                    ld hl, TMP_BYTE2  
                    ld (hl), 0x02

                    ; set file handle to close
                    ; from the one in memory
                    ld hl, TMP_BYTE
                    ld a, (hl)
                    ld hl, FILE_HDL
                    ld (hl), a

FCATFN_LOOP:
                    ;
                    ; read byte
                    ;

                    call FREADFH

                    ; return if we have an error
                    ; error is when a != 0 
                    cp 0x00
                    ret nz                     
                    
                    ; check the fread
                    ; result status
                    ld hl, OUT_BYTE1
                    ld a, (hl)
                    ; if != 1, is end of file
                    cp 0x01
                    jr nz, FCATFN_OK3

                    ; get received byte
                    ld hl, OUT_BYTE
                    ld a, (hl)

                    ; print it
                    call OUTCHAR

                    ; get received byte
                    ld hl, OUT_BYTE
                    ld a, (hl)

                    ; check if is new line
                    cp '\n'
                    jr nz, FCATFN_LOOP 

                    ; if it is print CR
                    ld a, '\r'
                    call OUTCHAR

                    jr FCATFN_LOOP

FCATFN_OK3:
                    ;
                    ; prepare close file
                    ;

                    ; signal that we are
                    ; entering fclose handle_id
                    ld hl, TMP_BYTE2  
                    ld (hl), 0x03

                    ; file handle id already 
                    ; in right address (was set on fread)

                    ;
                    ; close file
                    ;
                    call FCLOSEHL

                    ; return if we have an error
                    ; error is when a != 0 
                    cp 0x00
                    ret nz 


FCATFN_OK:
                    ;
                    ; operation ok
                    ;

                    ; reset the file handle id
                    ; stored on memory
                    ld hl, TMP_BYTE   
                    ld (hl), 0x00

                    ld a, 0x00
                    ret

;--------------------------------------------------------
; 
; Send file name or directory name
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

STRCPY:
                ;input: HL = base address of string you wish to copy
                ;       DE = where you want to copy it to.
                ;       The string must be null-terminated, 

                ld a,(hl)
                or a        ;compare A to 0.
                ;ret z
                jr z, STRCPYEND
                ld (de),a
                inc hl
                inc de
                jr STRCPY

STRCPYEND:
                ; end string
                ld (de),a
                ret

;--------------------------------------------

STRCAT:
                ;input: HL = base address of string you wish to copy
                ;       DE = where you want to copy it to.
                ;       The string must be null-terminated,

                ; find the end of destination
                ld a,(de)
                or a        ;compare A to 0.
                jr z, STRCAT1
                inc de
                jr STRCAT

STRCAT1:
                ; whe are at the end
                ; of destination string
                ; add the string in hl
                call STRCPY

                ret

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

;
; display one bye ascii hex followed by NL CR

; register A have the byte to display
; This is read as an 8 bit hex number
; push registers we need to preserve to
; stack before use this routine
SHOWHEXBYTECR:
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 
; ROM data
; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ROMDATA:

;
; command table
;

CMD_RET:             DB      "RET",0 ; not real command, only handle return key only
CMD_LOAD:            DB      "LOAD",0
CMD_SAVE:            DB      "SAVE",0
CMD_DEL:             DB      "DEL",0
CMD_LIST:            DB      "LIST",0
CMD_REN:             DB      "REN",0
CMD_COPY:            DB      "COPY",0
CMD_EXIST:           DB      "EXIST",0
CMD_MKDIR:           DB      "MKDIR",0
CMD_RMDIR:           DB      "RMDIR",0
CMD_CD:              DB      "CD",0
CMD_CWD:             DB      "CWD",0
CMD_EXIT:            DB      "EXIT",0
CMD_RESET:           DB      "RESET",0
CMD_SDIFS:           DB      "SDIFS",0
CMD_FOPEN:           DB      "FOPEN",0
CMD_FCLOSE:          DB      "FCLOSE",0
CMD_FWRITE:          DB      "FWRITE",0
CMD_FREAD:           DB      "FREAD",0
CMD_FGETPOS:         DB      "FTELL",0
CMD_FSEEKSET:        DB      "FSEEKSET",0
CMD_FSEEKCUR:        DB      "FSEEKCUR",0
CMD_FSEEKEND:        DB      "FSEEKEND",0
CMD_FREWIND:         DB      "FREWIND",0
CMD_FPEEK:           DB      "FPEEK",0
CMD_FCAT:            DB      "CAT",0
CMD_FWRITEB:         DB      "FWRITEB",0
CMD_FREADB:          DB      "FREADB",0
CMD_FTRUNCATE:       DB      "FTRUNCATE",0
CMD_LSOF:            DB      "LSOF",0
CMD_FGETSIZE:        DB      "FGETSIZE",0
CMD_FGETNAME:        DB      "FGETNAME",0
CMD_SETORG:          DB      "SETORG",0
CMD_FDSPACE:         DB      "FDSPACE",0
CMD_TDSPACE:         DB      "TDSPACE",0
CMD_RUN:             DB      "RUN",0

;
; strings definition
; 
STR_ZTGSDC:          DB      "ztg80 SDcard OS\n\r",0
STR_ZTGVER:          DB      "v1.07c\n\r",0

STR_OK:              DB      "OK\n\r",0
STR_ARG_ERROR:       DB      "Error\n\r",0

STR_CMD:             DB      ">",0
STR_CMD_NOTFOUND:    DB      "Command not found",0

STR_SDSTATUS_BAD:    DB      "Error: bad SDcIf status\n\r",0

STR_LOADOK:          DB      "File loaded\n\r",0
STR_SAVEOK:          DB      "File saved\n\r",0
STR_DIROK:           DB      "List end!\n\r",0
STR_REMOK:           DB      "File removed\n\r",0
STR_RENOK:           DB      "File renamed\n\r",0
STR_COPYOK:          DB      "File copied\n\r",0
STR_EXISTOK:         DB      "File verified\n\r",0
STR_MKDIROK:         DB      "Dir created\n\r",0
STR_RMDIROK:         DB      "Dir removed\n\r",0
STR_CHDIROK:         DB      "Dir changed\n\r",0
STR_CWDOK:           DB      "Current dir\n\r",0
STR_RESETOK:         DB      "SDcIf reset\n\r",0
STR_SDIFSOK:         DB      "SDcIf status\n\r",0

STR_COM:             DB      ".COM",0
STR_EXE:             DB      ".EXE",0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; RAM zone - variables
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

                    ORG    $FA00
                
RAMDATA:

; input
FILE_START:         DS $02 ; 2 bytes : memory start address / file open mode
FILE_LEN:           DS $02 ; 2 bytes : used as several purposes
FILE_NAME:          DS $41 ; 65 bytes
FILE_NAME1:         DS $41 ; 65 bytes
FILE_OMODE:         DS $02 ; 2 bytes : NOT USED
FILE_HDL:           DS $02 ; 2 bytes (but for hdl only first is used)

; reserved
BYTES_RESERVED:     DS $0F ; 15 bytes

; output
ERROR_CODE:         DS $01 ; : holds the error code, 0 is no error
OUT_BYTE:           DS $01 ; : store operation byte output
OUT_BYTE1:          DS $01 ; : store firmware byte operation result
OUT_LONG:           DS $04 ; 4 bytes
NUM_BYTES:          DS $02 ; 2 bytes
OUTBUFFER:          DS $41 ; 65 bytes

; cli wrk
FILE_CMD:           DS $10 ; 16 bytes: holds the command string
CLI_ORG:            DS $02 ; 2 bytes: Default address for load and run commands .com & .exe
TMP_BYTE:           DS $01 ; 1 byte: File handle id
TMP_BYTE2:          DS $01 ; 1 byte: multi operation stage (operation that call others)
TMP_WORD:           DS $02 ; 2 bytes

; cli input
LINETMP:            DS $41 ; 65 bytes
LINEBUF:            DS $91 ; 145 bytes

