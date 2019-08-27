ifeq ($(shell uname -s),Darwin)
  SO := dylib
else
	SO := so
endif

SHARED_LIB = libquadf.$(SO)
OBJ_FILE = quadf.o
SRC_FILE = quadf.c

all: $(SHARED_LIB)

$(SHARED_LIB): $(OBJ_FILE)
	clang -shared -o $(SHARED_LIB) $(OBJ_FILE)

$(OBJ_FILE): $(SRC_FILE)
	clang -c -O3 $(SRC_FILE)

clean:
	rm -f *.so *.o

