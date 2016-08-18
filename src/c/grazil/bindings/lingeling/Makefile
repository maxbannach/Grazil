CC=gcc
CFLAGS=-Wall -O3 -DNLGLOG -DNDEBUG -DNCHKSOL -DNLGLDRUPLIG -DNLGLYALSAT -DNLGLFILES -DNLGLDEMA

LIBS=-lm
LDEPS=
HDEPS=
AIGER=

LUALIB=/opt/local/lib
LUAINCLUDE=/opt/local/include
LINGELING=../../../../../extern/lingeling

all: targets

targets: Solver.so

Solver.so: Solver.c
	$(CC) $(CFLAGS) -Xlinker -dylib -o Solver.so Solver.c -I$(LINGELING) -L$(LINGELING) -llgl -L$(LUALIB) -llua -I$(LUAINCLUDE)


clean: 
	rm -f Solver.so

.PHONY: all targets clean clean-config clean-all
