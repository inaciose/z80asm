# RC2014 ZTGsdcard SCM app
Z80 RC2014 SCM app to use a sd card to load, save, list and remove files.
Requires the ZTGsdcard board.

https://github.com/inaciose/rc2014ss/tree/main/rcsdcard

# load and run
(past hex)
g 8000

# commands available
load name hexaddr
save name hexaddr hexlen
del name
list

# todo
rewrite to allow other programs calling routines at fixed addresses with conventions for calling, args data and returning data

