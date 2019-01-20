# Makefile using Lex to build

CC     = gcc
CFLAGS = -c -g -std=c99

LEX    = lex
LFLAGS =

LN     = gcc
LNFLAGS=

SRC    = calc.l mystack.c mystack.h
OBJ    = calc.o mystack.o

all:	calc

test: all
	./calc < test1.txt
	./calc < test2.txt

calc:	$(OBJ)
	$(LN) $(LNFLAGS) -o calc $(OBJ)

calc.o:	calc.c
	$(CC) $(CFLAGS) -o calc.o calc.c

calc.c: calc.l
	$(LEX) $(LFLAGS) -o calc.c calc.l
	
clean: 
	rm -f calc calc.c *.o