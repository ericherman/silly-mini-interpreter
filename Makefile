TARGET = interp
LIBS = -lm -ggdb3
CC = gcc
CFLAGS = -O2 -Wall -ggdb3

.PHONY: default all clean

default: $(TARGET)
all: default

OBJECTS = $(patsubst %.c, %.o, $(wildcard *.c))
HEADERS = $(wildcard *.h)
C_INCLUDES = command_enum.h.inc dispatch_table.h.inc
PERL_INCLUDES = lib/ASM/Enum.pm

%.o: %.c $(HEADERS) $(C_INCLUDES)
	$(CC) $(CFLAGS) -c $< -o $@

.PRECIOUS: $(TARGET) $(OBJECTS)

codegen: $(PERL_INCLUDES) $(C_INCLUDES)

$(C_INCLUDES):
	perl tools/gen_op_code.pl

$(PERL_INCLUDES):
	perl tools/gen_op_code.pl

$(TARGET): $(OBJECTS)
	$(CC) $(OBJECTS) -Wall $(LIBS) -o $@

clean:
	-rm -f *.o
	-rm -f *.inc
	-rm -f lib/ASM/Enum.pm
	-rm -f $(TARGET)
