bin: zt80mon2k.asm
	z80asm zt80mon2k.asm -o zt80mon2k.bin --list=zt80mon2k.lst

	#srec_cat zt80mon2k.bin -binary -zt80mon2k 0x8500 -output zt80mon2k.hex -intel -address-length=2

clean:
	rm -f zt80mon2k.bin zt80mon2k.lst
