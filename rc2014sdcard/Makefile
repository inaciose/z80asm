SRCF = sdcard
#SRCF = test01

all:
	z80asm $(SRCF).asm -o $(SRCF).bin --list=$(SRCF).lst

	srec_cat $(SRCF).bin -binary -offset 0x2000 -output $(SRCF).hex -intel -address-length=2

clean:
	rm -f *.bin *.lst
