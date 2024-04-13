# RC2014 ZTGsdcard SCM app v1.01 
Z80 RC2014 SCM app to use a sd card to load, save, list and remove files.
Requires the ZTGsdcard board.

https://github.com/inaciose/rc2014ss/tree/main/rcsdcard

compile origins (change on source)
- for ROM 0x2000
- for RAM 0x8000

# (load and) run
if run from ROM
- g 2000

if run from ROM
- (past hex)
- g 8000

# commands available
load name hexaddr
save name hexaddr hexlen
del name
list

# interface for external program usage

It is based on:
- store on memory positions for parameters
- read from memory positions for return

Memory positions for variables (passing parameters), the same for ROM and RAM versions
- 0xFAE0, store num bytes loaded (16 bits) :: Must be read by load routine to get num bytes loaded
- 0xFAE2, store the file start address (memory) (16 bits) :: must be set by read and save
- 0xFAE4, store the file len (memory) (16 bits) :: must be set by save
- 0xFAF6, store the filename string start address pointer (16 bits) :: must be set by read and save
Memory positions for calling routines (ROM or RAM version)
- save: call 0x2182 (call 0x8182)
- read: call 0x2225 (call 0x8225)

# C programs interface sample

Its suposed to be a notepad, but it is not. But it shows:
- how to save a block of memory to a file (with user input file name)
- how to read a file to memory, and get the number of bytes loaded (with user input file name)

The program is crude, and it realy not a notepad. 
To access the menu selection: 
- type "\m(enter)" at beguining of a line.
- Then input the number of the menu option. eg: 1(enter)

It can save and load.
if there is an sdcard interface error, quit the program, then reset the interface by typing the following on the monitor:
- o 40 f

# todo
DONE - rewrite to allow other programs calling routines at fixed addresses with conventions for calling, args data and nareturning data
make load quickier, done a litle bit.
make save quickier
add commands for more operations with changes in the status codes received from sdcard interface 

