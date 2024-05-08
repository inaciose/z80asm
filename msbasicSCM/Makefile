#SRCF = msbasic_grants.asm
SRCF = msbasic_original.asm
#SRCF = test.asm

msbasic.bin:
	z80asm $(SRCF) -o msbasic.bin --list=msbasic.lst

	srec_cat msbasic.bin -binary -offset 0x8000 -output msbasic.hex -intel -address-length=2

clean:
	rm -f *.bin *.lst *.hex
