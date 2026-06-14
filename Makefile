ifeq ($(shell uname -s),Darwin)
  SO := dylib
else
	SO := so
endif

SHARED_LIB = libquadf.$(SO)
SRC_FILE = quadf.c

.PHONY: all test clean

all: $(SHARED_LIB)

$(SHARED_LIB): $(SRC_FILE)
	gcc -shared -o $(SHARED_LIB) $(SRC_FILE) -lquadmath -fPIC -O3

test: all
	raco test quadf-test.rkt quadf-bigfloat-test.rkt

clean:
	rm -f *.so *.o *.dylib

