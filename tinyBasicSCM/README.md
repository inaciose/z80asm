# This project aims to build a tinybasic version that runs as an app on Small Computer Monitor

https://smallcomputercentral.com/small-computer-monitor/small-computer-monitor-v1-0/

You may find the history of tinybasic on the web. This project start with a version made on z80 assembly, and not in the 8080 one.
You can get the start code at the following url:

https://github.com/Obijuan/Z80-FPGA/tree/master/Tinybasic

Some initial remarks about how i will proceed

The routines based on the RST instruction must be converted to calls, because the basic will not run at 0x0000, but at 0x8500
The uart related code will be replaced by the SCM api to print a char, or get a char

# Journal
