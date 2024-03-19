## z80asm Basic.asm -o Basic.bin -l 2> Basic.lst
main.bin: main.asm
	z80asm main.asm -o main.bin --list=main.lst

	srec_cat main.bin -binary -offset 0x8500 -output main.hex -intel -address-length=2

clean:
	rm -f main.bin main.lst main.hex
