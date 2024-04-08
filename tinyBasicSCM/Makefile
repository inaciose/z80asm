## z80asm Basic.asm -o Basic.bin -l 2> Basic.lst
basic.bin: tinybasicscm.asm
	z80asm tinybasicscm.asm -o tinybasicscm.bin --list=tinybasicscm.lst

	srec_cat tinybasicscm.bin -binary -offset 0x8500 -output tinybasicscm.hex -intel -address-length=2

clean:
	rm -f tinybasicscm.bin tinybasicscm.lst
