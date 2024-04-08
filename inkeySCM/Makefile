SRCF = test.asm

test.bin:
	z80asm $(SRCF) -o test.bin --list=test.lst

	srec_cat test.bin -binary -offset 0x8500 -output test.hex -intel -address-length=2

clean:
	rm -f *.bin *.lst *.hex
