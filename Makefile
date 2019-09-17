ifeq ($(shell uname -s),Darwin)
  SO := dylib
else
	SO := so
endif

SHARED_LIB = libquadf.$(SO)
SRC_FILE = quadf.c

all: $(SHARED_LIB)

$(SHARED_LIB): $(SRC_FILE)
	gcc -shared -o $(SHARED_LIB) $(SRC_FILE) -lquadmath -fPIC -O3

clean:
	rm -f *.so *.o

