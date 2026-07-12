UNAME_S := $(shell uname -s)

# Follow the usual make conventions: command-line and environment overrides
# win over these defaults, and package-specific settings remain separately
# overridable when a toolchain needs them.
CPPFLAGS ?=
CFLAGS ?= -O3
LDFLAGS ?=
LDLIBS ?=
QUADMATH_LIBS ?= -lquadmath

ifeq ($(UNAME_S),Darwin)
  SHLIB_EXT := dylib
  SHARED_LDFLAGS ?= -dynamiclib
  PICFLAGS ?= -fPIC

  # Homebrew installs GNU GCC under a versioned name (for example gcc-15),
  # while /usr/bin/gcc is Apple Clang. Prefer the brewed compiler unless the
  # user supplied CC explicitly.
  HOMEBREW_GCC_PREFIX := $(shell command -v brew >/dev/null 2>&1 && brew --prefix gcc 2>/dev/null)
  ifneq ($(HOMEBREW_GCC_PREFIX),)
    HOMEBREW_GCC := $(firstword $(wildcard $(HOMEBREW_GCC_PREFIX)/bin/gcc-[0-9]*))
  endif
  ifneq ($(filter default undefined,$(origin CC)),)
    ifneq ($(HOMEBREW_GCC),)
      CC := $(HOMEBREW_GCC)
    else
      CC := cc
    endif
  endif
else ifneq ($(filter MINGW% MSYS% CYGWIN%,$(UNAME_S)),)
  SHLIB_EXT := dll
  SHARED_LDFLAGS ?= -shared
  PICFLAGS ?=
  ifneq ($(filter default undefined,$(origin CC)),)
    CC := gcc
  endif
else ifeq ($(OS),Windows_NT)
  SHLIB_EXT := dll
  SHARED_LDFLAGS ?= -shared
  PICFLAGS ?=
  ifneq ($(filter default undefined,$(origin CC)),)
    CC := gcc
  endif
else
  SHLIB_EXT := so
  SHARED_LDFLAGS ?= -shared
  PICFLAGS ?= -fPIC
  ifneq ($(filter default undefined,$(origin CC)),)
    CC := gcc
  endif
endif

SHARED_LIB := libquadf.$(SHLIB_EXT)
SRC_FILE := quadf.c

.PHONY: all test clean
.DELETE_ON_ERROR:

all: $(SHARED_LIB)

$(SHARED_LIB): $(SRC_FILE) Makefile
	$(CC) $(CPPFLAGS) $(CFLAGS) $(PICFLAGS) $(LDFLAGS) $(SHARED_LDFLAGS) -o $@ $< $(LDLIBS) $(QUADMATH_LIBS)

test: all
	raco test quadf-test.rkt quadf-bigfloat-test.rkt

clean:
	rm -f *.so *.o *.dylib *.dll
	rm -rf compiled private/compiled scribblings/compiled doc
