## z80asm Basic.asm -o Basic.bin -l 2> Basic.lst
basic.bin: tinybasic.asm
	z80asm tinybasic.asm -o tinybasic.bin --list=tinybasic.lst

clean:
	rm -f tinybasic.bin tinybasic.lst tinybasic.hex
