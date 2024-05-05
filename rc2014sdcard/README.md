# RC2014 ZTGsdcard SCM app v1.0x 
Z80 RC2014 SCM app to use a sd card to load, save, list and remove files.
This, and the firmware are under development.

Requires the ZTGsdcard board with the apropriate firmware version.
- https://github.com/inaciose/rc2014ss/tree/main/rcsdcard
- https://github.com/inaciose/stm32f103_ztgsdcard2

works with firmware: v1.06a - sync on fwrite byte (send result)

# Compilation
compile origins (change on source)
- for ROM 0x2000
- for RAM 0x8000

# (load and) run
if run from ROM
- g 2000

if run from RAM
- (past hex)
- g 8000

# SCM manager app 

Z80 exploration as SCM app 

+ Commands 
- load name hexaddr (load name HHHH)
- save name hexaddr hexlen (save name HHHH HHHH)
- del name
- list [name]
- ren names named
- copy names named
- exist name (reply: 0 no, 1 file, 2 directory)
- mkdir name 
- rmdir name
- cd name
- cwd
- sdifs
- reset
- exit
- cat

+ commands to add:
- help
- format
- volume (sd card info)

# File management program API
+ the commands above (cli exploration) are also to be part of the 
+ commands (also available on SCM app (for testing)
- fopen name HHHH                             name openmode
- fclose HH                                   handleid
- fwrite HH HH (write byte)                   handleid byte
- fwriteb HH HHHH HHHH (write n bytes)        handleid srcaddr numbytes
- fread HH (read byte)                        handleid 
- freadb HH HHHH HHHH (read n bytes)          handleid destaddr numbytes
- fgetpos HH                                  handleid
- fseekset HH HHHH HHHH                       handleid 	MSWORD LSWORD
- fseekcur HH HHHH HHHH                       handleid 	MSWORD LSWORD (signed) FFFF FFFF = -1
- fseekend HH HHHH HHHH                       handleid 	MSWORD LSWORD (signed) 0000 0000 = end
- frewind HH                                  handleid
- fpeek HH                                    handleid

+ commands to add:
- bool 	isDir () const
- bool 	isFile () const
- int 	write (const char *str)
- int16_t 	fgets (char *str, int16_t num, char *delim=0)

+ commands to add that requires changes in firmware:
- uint32_t 	fileSize () const
- bool 	truncate (uint32_t size)
- bool 	isOpen () const
- bool 	isRoot () const
- hdllist lsof()  (list openfiles)

# Programer API - Interface for external program usage
The developmente of API for interface with the programs is waiting for the development of the base I/O routines that is still a work in progress.
But older experiments show that can be like the basic file managment program api previously tested (described bellow), or some other way, like pass the arguments on the stack.

- on v1.06e the cli got more separated from operation implementation.
1. by storing operation results in variables that the cli can display later
3. by using separate entries for the cli requests and other program requests

The method used is based on:
- store parameters on know memory positions
- call routine at know memory position
- read return output from know memory

I belive that the addresses are more stable now, need to compile them.

The following information about memory address are not correct. Need an update.

Memory positions for variables (passing parameters), the same for ROM and RAM versions:
- 0xFAE0, store num bytes loaded (16 bits) :: Must be read by load routine to get num bytes loaded
- 0xFAE2, store the file start address (memory) (16 bits) :: must be set by read and save
- 0xFAE4, store the file len (memory) (16 bits) :: must be set by save
- 0xFAF6, store the filename string start address pointer (16 bits) :: must be set by read and save
Memory positions for calling routines (ROM or RAM version)
- save: call 0x2182 (call 0x8182)
- read: call 0x2225 (call 0x8225)


# C programs interface sample
(this is outdated... the notepad app need to be changed for the new API version)

Its suposed to be a notepad, but it is not. But it shows:
- how to save a block of memory to a file (with user input file name)
- how to read a file to memory, and get the number of bytes loaded (with user input file name)

The program is crude, and it realy not a notepad. 
To access the menu selection: 
- type "\m(enter)" at begining of a line.
- Then input the number of the menu option. eg: 1(enter)

It can save and load.
if there is an sdcard interface error, quit the program, then reset the interface by typing the following on the monitor:
- o 40 f

# todo
- Parameters and results passing.  

Possible options:
1. use registers to pass required parameters
2. use stack to pass required parameters and results
3. use memory locations to pass required parameters and results

Still stick at 3rd, and not forseen changes  

- make load quickier, (done a litle bit).
- make save quickier
- add commands for more operations

# operations status and command codes
https://docs.google.com/spreadsheets/d/1EDnzh6c8GuFteZskviRQ0HXl_1hdd2McFDgUcx4P_4A/edit?usp=sharing
