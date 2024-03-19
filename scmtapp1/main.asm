            org $8500
            ld	de, text	; load address for text to display.
            call	display		; call display
            ret			; we are done

display:
            ld	c, $06		; load display routine from SCM API
            rst	$30		; exec display routing
            ret			; we are done

text:
            db	"scmtapp1, Hello, World\n\r",0 ; define string to display