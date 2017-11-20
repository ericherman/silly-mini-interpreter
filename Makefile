LDFLAGS += -ggdb3
CCFLAGS += -ggdb3
CCFLAGS += -O2

SOURCES=interp.c
OBJECTS=$(patsubst %.c, %.o, $(SOURCES))

all: interp

%.o:
	$(CC) -o $@ -c $*.c $(CCFLAGS)

interp: $(OBJECTS)
	$(CC) $(CCFLAGS) $(OBJECTS) -o $@ $(LDFLAGS)

clean:
	@rm -f *~ core *.o *.so

realclean: clean
	@rm interp

.PHONY: all clean realclean

