# quad-fp.rkt

[![CI](https://github.com/shaobo-he/quad-fp.rkt/actions/workflows/ci.yml/badge.svg?branch=develop)](https://github.com/shaobo-he/quad-fp.rkt/actions/workflows/ci.yml)

A toy [Racket](https://racket-lang.org) binding to GCC's
[libquadmath](https://gcc.gnu.org/onlinedocs/libquadmath/), exposing IEEE 754
**quadruple-precision** (128-bit, `__float128`) floating point to Racket — about
34 significant decimal digits, versus ~16 for Racket's native double flonums.

## Layout

| File / dir                  | Role                                                            |
| --------------------------- | -------------------------------------------------------------- |
| `quadf.c`                   | C shim over libquadmath; treats each quad as an opaque 16 bytes |
| `quadf.rkt`                 | `racket/base` FFI bindings (untyped)                           |
| `quadf-typed.rkt`           | Typed Racket wrapper exposing an opaque `Quad-Flonum` type      |
| `main.rkt`                  | Package entry point — `(require quad-fp)`                       |
| `quadf-test.rkt`            | `rackunit` unit tests                                          |
| `quadf-bigfloat-test.rkt`   | `rackcheck` property tests vs. `math/bigfloat` at 113-bit      |
| `info.rkt`                  | Package metadata, dependencies, and the install hook           |
| `private/build-native.rkt`  | Compiles `libquadf` from source at install time                |
| `scribblings/quad-fp.scrbl` | API documentation                                              |

## Requirements

- GCC with `libquadmath` and `quadmath.h` (ships with GCC on most Linux distros)
- Racket (provides `racket` and `raco`)

On macOS, `/usr/bin/gcc` is Apple Clang and does not provide libquadmath.
Install GCC with Homebrew; the package installer and Makefile automatically
detect Homebrew's versioned GCC executable:

```sh
brew install gcc
raco pkg install --auto --name quad-fp
```

If auto-detection fails or a specific compiler is required, override `CC`
(substitute the installed version):

```sh
CC=gcc-15 raco pkg install --auto --name quad-fp
```

Both build paths honor `CC`; `CPPFLAGS`, `CFLAGS`, and `PICFLAGS`;
`LDFLAGS` and `SHARED_LDFLAGS`; and `LDLIBS` and `QUADMATH_LIBS`.

## Install

As a Racket package (once published to the
[catalog](https://pkgs.racket-lang.org), or from a local checkout):

```sh
raco pkg install quad-fp          # from the catalog
raco pkg install                  # or from inside a clone of this repo
```

Installation compiles the native `libquadf` shim from source via the
`info.rkt` install hook, so the GCC + libquadmath requirement above applies.

## Build & test

For development, the `Makefile` builds the shim directly:

```sh
make        # builds libquadf.so (libquadf.dylib on macOS)
make test   # builds, then runs the unit + property suites
```

`make test` assumes the Racket build/test dependencies declared in `info.rkt`
(`rackcheck-lib`, `math-lib`, and `rackunit-lib`) are installed. From a fresh
clone, bootstrap them by linking/installing the package once before invoking
the Makefile:

```sh
raco pkg install --auto --name quad-fp
make clean  # force the Makefile to rebuild the installer-created native shim
make test
```

The same compiler auto-detection and build-variable overrides apply to both
commands.

The property suite (`quadf-bigfloat-test.rkt`) checks the operations against
[`math/bigfloat`](https://docs.racket-lang.org/math/bigfloat.html) at 113-bit
precision (the binary128 significand): `+ - * /` match bigfloat *bit for bit*
for the generated finite inputs. `sqrt` and `fma` use a relative-error bound
of `2^-110` (roughly 4–8 ULP, depending on the significand); the tested
transcendentals, including `lgamma`, use `2^-106` (roughly 64–128 ULP); and
`tgamma` uses the version-tolerant `2^-90` (roughly 4–8 million ULP). That
last bound still requires about 27 correct decimal digits, but reflects the
much larger variation seen across libquadmath versions. When the reference is
zero, the same numeric limits are absolute rather than relative. These are
regression-test bounds, not guarantees made by libquadmath for every input or
release.

The modules locate `libquadf` relative to their own source via
`define-runtime-path`, so once it's built (next to the `.rkt` files, as `make`
does) the binding works from any working directory.

## Usage

```racket
#lang racket/base
(require quad-fp)

(define a (double-flonum->quad-flonum 1.0))
(define b (double-flonum->quad-flonum 1e-20))

;; In double, 1.0 + 1e-20 == 1.0 — the addend is lost. In quad it survives:
(quad-flonum->string (qf+ a b))
;; => "1.00000000000000000000999999999999995"
(qf= (qf+ a b) a)                        ; => #f
```

The API mirrors libquadmath's real-valued surface:

- **Arithmetic** — `qf+ qf- qf* qf/`
- **Elementary** — roots/powers (`qfsqrt qfcbrt qfpow qfhypot`), exp/log
  (`qfexp qfexp2 qfexpm1 qflog qflog2 qflog10 qflog1p`), trig and inverses
  (`qfsin qfcos qftan qfasin qfacos qfatan qfatan2`), hyperbolics
  (`qfsinh … qfatanh`)
- **Rounding** — `qfceil qffloor qftrunc qfround qfrint qfnearbyint qfabs`
- **Special** — `qferf qferfc qflgamma qftgamma`, Bessel `qfj0 qfj1 qfy0 qfy1`
- **Misc binary** — `qffmod qfremainder qfcopysign qffdim qfmax qfmin
  qfnextafter` and the fused multiply-add `qffma`
- **Comparison** — `qf= qf< qf<= qf> qf>=`
- **Classification** — `qfnan? qfinfinite? qffinite? qfsignbit?`
- **Conversion** — `double-flonum->quad-flonum` / `quad-flonum->double-flonum`,
  full-precision `string->quad-flonum` / `quad-flonum->string`, and (typed
  module) `quad-flonum->bytes`
- **Constants** — `quad-pi quad-e quad-sqrt2 …`, plus `quad-max quad-epsilon`
  and format characteristics including `quad-mant-dig` (113), `quad-dig` (33
  decimal digits of precision), and `quad-decimal-dig` (36 digits for a
  binary128 decimal round trip)

Decimal conversion is locale-independent and always uses `.` as the decimal
separator. Apart from surrounding C-locale whitespace,
`string->quad-flonum` requires the whole string to be a valid number instead
of silently accepting a numeric prefix. `quad-flonum->string` accepts a
precision from 1 through 12000 (default 36), sizes its output dynamically, and
returns the complete representation without fixed-buffer truncation.

`qflgamma` ultimately calls libquadmath's `lgammaq`, which writes the
process-global C variable `signgam`. It is not safe to run `qflgamma`
concurrently with another `qflgamma` call or with native code outside the
package that calls `lgammaq` or accesses `signgam`. Serialize all such access
at the application level.

See the [Scribble docs](scribblings/quad-fp.scrbl) for the full list. Complex
(`__complex128`) functions and the multi-result functions (`frexpq`, `sincosq`,
…) are not yet bound. `qfexp2` is implemented via `powq`, and `logbq` /
`issignalingq` are intentionally omitted, since those symbols are absent from
some older libquadmath builds (binding them made `libquadf` fail to load).

## License

[MIT](LICENSE) © Shaobo He
