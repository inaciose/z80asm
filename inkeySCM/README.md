# RC2014 - SCM - Get the char (key) typed in the terminal witout enter is pressed

Get a char from a serial/uart terminal without need to press enter.
Usefull for using it in games.

Using SCM (Small Computer Monitor) API
API 0x01 - getc, console character input
API 0x02 - putc, console character ouput
API 0x03 - getac, console input status(check if char is available to get it, return it on l register (ont direct scm api is on a register a))

Steve Cousins help on:
- https://groups.google.com/g/rc2014-z80/c/UKNog_LCKe4

See also:
- https://github.com/inaciose/z88dks/tree/main/rc2014scmapi

SCM
- https://smallcomputercentral.com/
