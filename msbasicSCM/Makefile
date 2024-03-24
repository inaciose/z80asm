bmsasic.bin: SCMon_BASIC.asm
	z80asm SCMon_BASIC.asm -o SCMon_BASIC.bin --list=SCMon_BASIC.lst

	srec_cat SCMon_BASIC.bin -binary -offset 0x8500 -output SCMon_BASIC.hex -intel -address-length=2

clean:
	rm -f SCMon_BASIC.bin SCMon_BASIC.lst SCMon_BASIC.hex
