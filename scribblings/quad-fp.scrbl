#lang scribble/manual
@(require (for-label racket/base
                     quad-fp))

@title{quad-fp: quadruple-precision floating point}
@author{Shaobo He}

@defmodule[quad-fp]

A toy Racket FFI binding to GCC's
@hyperlink["https://gcc.gnu.org/onlinedocs/libquadmath/"]{libquadmath},
exposing IEEE 754 quadruple-precision (128-bit, @tt{__float128}) floating
point — roughly 34 significant decimal digits, versus the ~16 of Racket's
native double @tech[#:doc '(lib "scribblings/reference/reference.scrbl")]{flonums}.

Values are opaque: a quad is shuttled across the FFI boundary as 128 bits and
is only ever produced or consumed by the operations below.

@margin-note{The binding loads a native shared library (@tt{libquadf}) that is
compiled from source at install time, so a C toolchain with libquadmath must be
present. See the package README for details.}

@section{Predicate}

@defproc[(Quad? [v any/c]) boolean?]{
  Returns @racket[#t] if @racket[v] is a quad-precision value produced by this
  library, @racket[#f] otherwise.}

@section{Conversion}

@deftogether[(
  @defproc[(double-flonum->quad-flonum [x flonum?]) Quad?]
  @defproc[(quad-flonum->double-flonum [q Quad?]) flonum?]
)]{
  Convert between a Racket double @racket[flonum?] and a quad. Widening a
  double is exact; narrowing back to a double rounds to nearest.}

@deftogether[(
  @defproc[(string->quad-flonum [s string?]) Quad?]
  @defproc[(quad-flonum->string [q Quad?] [precision exact-integer? 36]) string?]
)]{
  Parse a decimal string into a quad (via @tt{strtoflt128}), and render a quad
  to a decimal string with @racket[precision] significant digits (via
  @tt{quadmath_snprintf}). The default of 36 digits round-trips binary128
  exactly.}

@defproc[(quad-flonum->bytes [q Quad?]) bytes?]{
  Returns the 16-byte little-endian representation of @racket[q]'s
  @tt{__float128} bit pattern.}

@section{Arithmetic}

@deftogether[(
  @defproc[(qf+ [a Quad?] [b Quad?]) Quad?]
  @defproc[(qf- [a Quad?] [b Quad?]) Quad?]
  @defproc[(qf* [a Quad?] [b Quad?]) Quad?]
  @defproc[(qf/ [a Quad?] [b Quad?]) Quad?]
)]{
  Quad-precision addition, subtraction, multiplication, and division.}

@section{Elementary functions}

@deftogether[(
  @defproc[(qfabs [a Quad?]) Quad?]
  @defproc[(qfsqrt [a Quad?]) Quad?]
  @defproc[(qfcbrt [a Quad?]) Quad?]
  @defproc[(qfpow [a Quad?] [b Quad?]) Quad?]
  @defproc[(qfhypot [a Quad?] [b Quad?]) Quad?]
)]{
  Absolute value, square and cube roots, @racket[a] raised to @racket[b], and
  @racket[(qfsqrt (qf+ (qf* a a) (qf* b b)))] without overflow.}

@deftogether[(
  @defproc[(qfexp [a Quad?]) Quad?]
  @defproc[(qfexp2 [a Quad?]) Quad?]
  @defproc[(qfexpm1 [a Quad?]) Quad?]
  @defproc[(qflog [a Quad?]) Quad?]
  @defproc[(qflog2 [a Quad?]) Quad?]
  @defproc[(qflog10 [a Quad?]) Quad?]
  @defproc[(qflog1p [a Quad?]) Quad?]
)]{
  Exponentials (@racket[qfexpm1] computes @math{e^x-1} accurately near 0) and
  logarithms (@racket[qflog1p] computes @math{log(1+x)}).}

@deftogether[(
  @defproc[(qfsin [a Quad?]) Quad?]
  @defproc[(qfcos [a Quad?]) Quad?]
  @defproc[(qftan [a Quad?]) Quad?]
  @defproc[(qfasin [a Quad?]) Quad?]
  @defproc[(qfacos [a Quad?]) Quad?]
  @defproc[(qfatan [a Quad?]) Quad?]
  @defproc[(qfatan2 [a Quad?] [b Quad?]) Quad?]
)]{
  Trigonometric functions and their inverses; @racket[qfatan2] is the
  two-argument arctangent.}

@deftogether[(
  @defproc[(qfsinh [a Quad?]) Quad?]
  @defproc[(qfcosh [a Quad?]) Quad?]
  @defproc[(qftanh [a Quad?]) Quad?]
  @defproc[(qfasinh [a Quad?]) Quad?]
  @defproc[(qfacosh [a Quad?]) Quad?]
  @defproc[(qfatanh [a Quad?]) Quad?]
)]{
  Hyperbolic functions and their inverses.}

@section{Rounding}

@deftogether[(
  @defproc[(qfceil [a Quad?]) Quad?]
  @defproc[(qffloor [a Quad?]) Quad?]
  @defproc[(qftrunc [a Quad?]) Quad?]
  @defproc[(qfround [a Quad?]) Quad?]
  @defproc[(qfrint [a Quad?]) Quad?]
  @defproc[(qfnearbyint [a Quad?]) Quad?]
)]{
  Round toward @math{+∞}, @math{-∞}, zero, and nearest (ties away from zero for
  @racket[qfround]; using the current rounding mode for @racket[qfrint] and
  @racket[qfnearbyint]).}

@section{Special functions}

@deftogether[(
  @defproc[(qferf [a Quad?]) Quad?]
  @defproc[(qferfc [a Quad?]) Quad?]
  @defproc[(qflgamma [a Quad?]) Quad?]
  @defproc[(qftgamma [a Quad?]) Quad?]
  @defproc[(qfj0 [a Quad?]) Quad?]
  @defproc[(qfj1 [a Quad?]) Quad?]
  @defproc[(qfy0 [a Quad?]) Quad?]
  @defproc[(qfy1 [a Quad?]) Quad?]
)]{
  Error functions, log-gamma and gamma, and Bessel functions of the first
  (@racket[qfj0], @racket[qfj1]) and second (@racket[qfy0], @racket[qfy1])
  kind, orders 0 and 1.}

@section{Other binary functions}

@deftogether[(
  @defproc[(qffmod [a Quad?] [b Quad?]) Quad?]
  @defproc[(qfremainder [a Quad?] [b Quad?]) Quad?]
  @defproc[(qfcopysign [a Quad?] [b Quad?]) Quad?]
  @defproc[(qffdim [a Quad?] [b Quad?]) Quad?]
  @defproc[(qfmax [a Quad?] [b Quad?]) Quad?]
  @defproc[(qfmin [a Quad?] [b Quad?]) Quad?]
  @defproc[(qfnextafter [a Quad?] [b Quad?]) Quad?]
  @defproc[(qffma [a Quad?] [b Quad?] [c Quad?]) Quad?]
)]{
  Floating-point remainder, IEEE remainder, sign copying, positive difference,
  maximum, minimum, next representable value toward @racket[b], and the fused
  multiply-add @racket[(qf+ (qf* a b) c)] computed with a single rounding.}

@section{Comparison}

@deftogether[(
  @defproc[(qf= [a Quad?] [b Quad?]) boolean?]
  @defproc[(qf< [a Quad?] [b Quad?]) boolean?]
  @defproc[(qf<= [a Quad?] [b Quad?]) boolean?]
  @defproc[(qf> [a Quad?] [b Quad?]) boolean?]
  @defproc[(qf>= [a Quad?] [b Quad?]) boolean?]
)]{
  Quad-precision comparisons, returning Racket booleans.}

@section{Classification}

@deftogether[(
  @defproc[(qfnan? [a Quad?]) boolean?]
  @defproc[(qfinfinite? [a Quad?]) boolean?]
  @defproc[(qffinite? [a Quad?]) boolean?]
  @defproc[(qfsignbit? [a Quad?]) boolean?]
)]{
  Test for NaN, infinity, finiteness, and a set sign bit.}

@section{Constants}

@deftogether[(
  @defthing[quad-pi Quad?]
  @defthing[quad-pi/2 Quad?]
  @defthing[quad-pi/4 Quad?]
  @defthing[quad-1/pi Quad?]
  @defthing[quad-2/pi Quad?]
  @defthing[quad-2/sqrt-pi Quad?]
  @defthing[quad-e Quad?]
  @defthing[quad-log2e Quad?]
  @defthing[quad-log10e Quad?]
  @defthing[quad-ln2 Quad?]
  @defthing[quad-ln10 Quad?]
  @defthing[quad-sqrt2 Quad?]
  @defthing[quad-1/sqrt2 Quad?]
)]{
  The mathematical constants from libquadmath's @tt{M_*q} macros (π, π/2, π/4,
  1/π, 2/π, 2/√π, e, log₂e, log₁₀e, ln 2, ln 10, √2, 1/√2).}

@deftogether[(
  @defthing[quad-max Quad?]
  @defthing[quad-min Quad?]
  @defthing[quad-epsilon Quad?]
  @defthing[quad-denorm-min Quad?]
)]{
  Largest finite, smallest positive normal, machine epsilon, and smallest
  positive subnormal (@tt{FLT128_MAX}, @tt{FLT128_MIN}, @tt{FLT128_EPSILON},
  @tt{FLT128_DENORM_MIN}).}

@deftogether[(
  @defthing[quad-mant-dig exact-integer?]
  @defthing[quad-decimal-dig exact-integer?]
  @defthing[quad-min-exp exact-integer?]
  @defthing[quad-max-exp exact-integer?]
  @defthing[quad-min-10-exp exact-integer?]
  @defthing[quad-max-10-exp exact-integer?]
)]{
  Format characteristics: mantissa bits (113), round-trippable decimal digits
  (33), and the binary and decimal exponent ranges.}

@section{Example}

@racketblock[
  (require quad-fp)
  (define a (double-flonum->quad-flonum 1.0))
  (define b (double-flonum->quad-flonum 1e-20))
  (code:comment "In double, 1.0 + 1e-20 == 1.0; in quad the addend survives:")
  (qf= (qf+ a b) a)
  (code:comment "=> #f")
  (quad-flonum->string (qf* quad-pi quad-pi))
  (code:comment "=> \"9.86960440108935861883449099987615081\"")
]
