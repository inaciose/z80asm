# z80asm
Hold my projects using z80asm assembler

Install
- sudo apt install z80asm z80dasm srecord

Optional
- sudo apt install openmsx

# Using z80asm with RC2014
Some help on using z80asm on RC2014 based system

Sample "helloworld.asm":

<code>
org $8000

	ld	de, text	; load address for text to display.
	call	display		; call display
	ret			; we are done

display:
	ld	c, $06		; load display routine from SCM API
	rst	$30		; exec display routing
	ret			; we are done

text:	
	dm	"Hello, World",0 ; define string to display
</code>

Assemble the source to a binary file using z80asm:
- z80asm -i helloworld.asm -o helloworld.bin
Converting it to Intel Hex format (linux)
- srec_cat helloworld.bin -binary -offset 0x8000 -output helloworld.hex -intel -address-length=2

Running it on the RC2014 with SCM
Copy the resulting Hex data and paste it to the cli of SCM
We got: *Ready
run with: g 8000

Note: the offset parm, and g value must match the origin in the assembly code

https://www.kianryan.co.uk/2023-01-05-getting-started-with-z80asm-on-the-rc2014/
