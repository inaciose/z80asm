; RC2014 - SCM - get char from serial/uart 
; without pressing the enter key

            ORG   $8500 

loop:
            ; check to see if there is
            ; an char available in uart
            call getac
            ld a, l
            cp 0
            jr z, loop

            ; print the char checked
            ; with getac. The char is
            ; still in uart until getc
            call putc

            ; get the char available
            call getc

            ; print the char retrived
            ld a, l
            call putc

            ; if we did not make any putc
            ; the char is not showed
            ; on the screen

ret


getc:
            ; input: none
            ; return: register l 
            ; have the char on acia
            ; or zero if a char is not available

            push af
            push bc;
            push de

            ld      c, 0x01
            rst     0x30
            ld      l,a     ; return the 
            ld      h,0     ; result in hl

            pop de
            pop bc
            pop af

            ret

getac:
            ; input: none
            ; return: register l 
            ; have the char on acia
            ; or zero if a char is not available

            push af
            push bc;
            push de

            ld      c, 0x03
            rst     0x30

            jr z, aget_noa
            ; is available
            ld      l,a
            jr aget_end

            aget_noa:
            ; not available
            ld      l,0 
        
            aget_end:
            ld      h,0     ; return the result in hl

            pop de
            pop bc
            pop af

            ret

putc:
            ; input: register a 
            ; must have the 
            ; char to print
            ; return: none

            push af
            push bc;
            push de
            push hl

            ld c, 0x02
            rst 0x30
            
            pop hl
            pop de
            pop bc
            pop af

            ret