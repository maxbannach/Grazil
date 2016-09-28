CC=gcc
CFLAGS=

LUAINCLUDE=/usr/include/lua5.3

MEX=/usr/local/MATLAB/R2016a/bin/mex

all: targets

targets: grazil

grazil:
	echo -n "#define LUASCRIPT \"" > luascript.h
	pwd | tr -d '\n' >> luascript.h
	echo "/grazil.lua\"" >> luascript.h
	$(MEX) -I$(LUAINCLUDE) -llua5.3 grazil.c

clean:
	rm -f grazil.mexa64

.PHONY: all targets clean clean-config clean-all
