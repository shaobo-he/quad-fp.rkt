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

The property suite (`quadf-bigfloat-test.rkt`) checks the operations against
[`math/bigfloat`](https://docs.racket-lang.org/math/bigfloat.html) at 113-bit
precision (the binary128 significand): `+ - * /` match bigfloat *bit for bit*
(they're correctly rounded on every libquadmath); `sqrt` and `fma` are bit-exact
on recent libquadmath and within a few ULP on older builds; and the
transcendentals are held to a loose ULP bound (the gamma functions loosest, as
their accuracy varies most across libquadmath versions).

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
(quad-flonum->double-flonum (qf+ a b))   ; => 1.0000000000000001e0 worth of quad
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
  and format characteristics like `quad-mant-dig` (113)

See the [Scribble docs](scribblings/quad-fp.scrbl) for the full list. Complex
(`__complex128`) functions and the multi-result functions (`frexpq`, `sincosq`,
…) are not yet bound. `qfexp2` is implemented via `powq`, and `logbq` /
`issignalingq` are intentionally omitted, since those symbols are absent from
some older libquadmath builds (binding them made `libquadf` fail to load).

## License

[MIT](LICENSE) © Shaobo He
