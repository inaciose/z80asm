# This project aims to build a tinybasic version that runs as an app on Small Computer Monitor

https://smallcomputercentral.com/small-computer-monitor/small-computer-monitor-v1-0/

You may find the history of tinybasic on the web. This project start with a version made on z80 assembly, and not in the 8080 one.
You can get the start code at the following url:

https://github.com/Obijuan/Z80-FPGA/tree/master/Tinybasic

Some initial remarks about how i will proceed

The routines based on the RST instruction must be converted to calls, because the basic will not run at 0x0000, but at 0x8500
The uart related code will be replaced by the SCM api to print a char, or get a char

# Journal
# 1:
Changed all "RST HH" by "CALL RSTHH"
Replace code for uart init and outc & getc

Compiler reports :
"DWA:1: warning: byte value 262 (0x106) truncated"
for several bytes.

DWA is a macro

DWA:    MACRO WHERE
        DB   (WHERE >> 8) + 128
        DB   WHERE & 0FFH
        ENDM

Its used near the final
TAB1:                                   ;DIRECT COMMANDS
        DB 'LIST'
        DWA LIST


- Failed

# 2
hex converter origin set to 8500
stack pointer uncommented
macro changed to (per chatgpt sugestion):

DWA:    MACRO WHERE
        DW   (WHERE - $) + 128
        DB   WHERE & 0FFH
        ENDM

explanation:
"When you change the program's starting address from ORG 0000H to ORG 8500H, you need to make some adjustments to your code to ensure that the macro works correctly. This is because the DWA macro is using the absolute address of the memory location it is being called from. Here's a way to modify the macro to work regardless of the source address: (above code)"
"When using WHERE - $, you are calculating the relative offset from the current program counter position ($) to the address where the DWA is called (WHERE). This will ensure the value is calculated correctly regardless of the originating address."

- failed after press CR
screen:
"Z80 TINY BASIC 2.0g
PORTED BY DOUG GABBARD, 2017

OK
>let a=5
Trap
PC:4453 AF:0D37 BC:0D3F DE:0D37 HL:4452 IX:8460 IY:0000 Flags:---H-PNC"

# 3
found 2 RST XX that need to be replaced
- failed at press CR
screen:
"Z80 TINY BASIC 2.0g
PORTED BY DOUG GABBARD, 2017

OK
>let a=10
"

program hangs

# 4
I didnt realise yet, why it marks the 7 bit of HI address in the table to make it a jump address.
does the table have entries that arent jump addresses
checked the result of the macro in the original code and notice the pattern

cmd  jadr radr
list 8169 0169
run  813c 0136
next 8246 0246
let  830a 030a

next, changed the macro to:

DWA:    MACRO WHERE
        DB   WHERE >> 8
        DB   WHERE & 0FFH
        ENDM

this way, the correct address is generated, but in reality the 7 bit is always high
so i remove the code that reset it.

;AND 7FH                         ;MASK OFF BIT 7

- failed, not get expected response (program dont hangs, still running)
screen:
"Z80 TINY BASIC 2.0g
PORTED BY DOUG GABBARD, 2017

OK
>let a = 10
WHAT?

OK
>"

# 5
Changes in the ORG at the end of file
        ORG  0A000H
        ORG  0D100H ; Last 256 bytes of RAM

- failed, not get expected response, accept prog lines, error on command (program dont hangs, still running)
screen: 
"Z80 TINY BASIC 2.0g
PORTED BY DOUG GABBARD, 2017
OK
>10 a=5
>20 a=a+1
>30 print a
>run
WHAT?

OK
>"

# 6
changes, i dont know...
some debug changes and debug helper code added
notice that the commands must be all capital case
- success (must be better tested)
>LIST
  10 A=1
  20 B=5
  30 C=A+B
  40 PRINT C

OK
>RUN
15AC     6

# 7
some clean up of debug code
- sucess, project closed (but it must be better tested!), 
note: it was save to sdcard and can be loaded from sdcard
- tbas1.zta

# 8
clean exit to SMC, translate comments, add more comments,
add notice to mod on initial display text
- success
