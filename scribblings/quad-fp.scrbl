#lang scribble/manual
@(require scribble/example
          (for-label racket/base
                     racket/contract
                     quad-fp))

@(define quad-eval (make-base-eval))

@title{quad-fp: quadruple-precision floating point}
@author{Shaobo He}

@defmodule[quad-fp]

A toy Racket FFI binding to GCC's
@hyperlink["https://gcc.gnu.org/onlinedocs/libquadmath/"]{libquadmath},
exposing IEEE 754 quadruple-precision (128-bit, @tt{__float128}) floating
point — roughly 34 significant decimal digits, versus the ~16 of Racket's
native double @tech[#:doc '(lib "scribblings/reference/reference.scrbl")]{flonums}.

Values are opaque: a quad is shuttled across the FFI boundary as 128 bits and
is only ever produced or consumed by the operations below. The @tt{qf…}
operations mirror libquadmath's @tt{…q} C functions — @racket[qfsqrt] wraps
@tt{sqrtq}, @racket[qffma] wraps @tt{fmaq}, and so on — so libquadmath's own
documentation maps directly onto this API.

@examples[#:eval quad-eval
  (require quad-fp)
  (define a (double-flonum->quad-flonum 1.0))
  (define b (double-flonum->quad-flonum 1e-20))
  (qf= (qf+ a b) a)
  (quad-flonum->string (qf* quad-pi quad-pi))
]
@(close-eval quad-eval)

@margin-note{The binding loads a native shared library (@tt{libquadf}) that is
compiled from source at install time, so a C toolchain with libquadmath must be
present. See the package README for details.}

@section[#:tag "accuracy"]{Accuracy}

The arithmetic operators are compiled as GCC @tt{__float128} operations; the
elementary and special functions delegate to libquadmath. The exception is
@racket[qfexp2], which uses @tt{powq(2,x)} for compatibility with libquadmath
versions that do not export @tt{exp2q}. Accuracy therefore varies across GCC
versions. The package's property tests compare the core operations and
functions for which there is a corresponding
@hyperlink["https://docs.racket-lang.org/math/bigfloat.html"]{@tt{math/bigfloat}}
operation at 113-bit precision. Their regression bounds are:

@itemlist[
  @item{@racket[qf+], @racket[qf-], @racket[qf*], @racket[qf/], and
        @racket[qfabs] must match @tt{math/bigfloat} bit for bit for the
        generated finite inputs.}
  @item{@racket[qfsqrt] and @racket[qffma] use the relative-error bound
        @math{2^{-110}} (roughly 4–8 ulps, depending on the significand). They
        are bit-exact on recent libquadmath builds, while older implementations
        may be only faithfully rounded or may double-round.}
  @item{The tested transcendental functions, including @racket[qflgamma], are
        held to relative error @math{2^{-106}} (roughly 64–128 ulps).
        @racket[qftgamma] varies much more across libquadmath versions and uses
        @math{2^{-90}} (roughly 4–8 million ulps), which still requires about
        27 correct decimal digits.}
]

These are conservative regression-test bounds, not universal accuracy
guarantees from libquadmath. Functions without a @tt{math/bigfloat} counterpart,
including the Bessel functions, are not covered by those property comparisons.
When a reference result is zero, the suite treats the same numeric bound as an
absolute rather than relative error limit.
Do not rely on bit-for-bit reproducibility of transcendental results across
libquadmath versions, especially for @racket[qftgamma].

@section[#:tag "performance"]{Performance}

Every operation crosses the Racket/C boundary and allocates a result. That fixed
cost is most visible for arithmetic and much less important for expensive
transcendental functions. Exact timings depend on the Racket implementation,
compiler, CPU, and libquadmath version, so measure on the deployment system:

@verbatim|{
make bench
QUADF_BENCH_ITERATIONS=500000 make bench
}|

The benchmark reports nanoseconds per call, the Racket version, machine type,
and iteration count. It measures the untyped @racketmodfont{quad-fp/quadf}
layer. The default @racketmodname[quad-fp] adds Typed Racket contracts at the
boundary.

The untyped module uses @racketmodfont{ffi/unsafe}, bypasses the public typed
contracts, and exposes low-level representation accessors. Treat it as an
optimization interface: use it only after profiling, pass values produced by
this package, and do not depend on its extra exports remaining stable.

@section{Datatype}

@defidform[#:kind "type" Quad-Flonum]{
  The type of quadruple-precision values. The public module is a Typed Racket
  facade over the untyped FFI core, so in typed code every operation here
  consumes and produces @racket[Quad-Flonum]s. The type is opaque — a value is
  created only by a
  conversion (such as @racket[double-flonum->quad-flonum] or
  @racket[string->quad-flonum]) or a named constant, never written as a literal.
  The module is equally usable from untyped Racket, where @racket[Quad-Flonum]
  does not appear and the predicate @racket[Quad?] takes its place.}

@defproc[(Quad? [v any/c]) boolean?]{
  Returns @racket[#t] if @racket[v] is a @racket[Quad-Flonum] produced by this
  library, @racket[#f] otherwise — @racket[Quad-Flonum]'s runtime counterpart,
  and the predicate the procedure signatures below are written against.}

The public entry point preserves its type information when used from Typed
Racket:

@racketmod[
typed/racket/base
(require quad-fp)
(: square (Quad-Flonum -> Quad-Flonum))
(define (square x) (qf* x x))
(quad-flonum->string (square (string->quad-flonum "1.25")))
]

This usage is compiled and exercised by the package's typed-client test.

@section{Conversion}

@deftogether[(
  @defproc[(double-flonum->quad-flonum [x flonum?]) Quad?]
  @defproc[(quad-flonum->double-flonum [q Quad?]) flonum?]
)]{
  Convert between a Racket double @racket[flonum?] and a quad. Widening a
  double is exact; narrowing back to a double rounds to nearest.}

@deftogether[(
  @defproc[(string->quad-flonum [s string?]) Quad?]
  @defproc[(quad-flonum->string [q Quad?]
                                 [precision (integer-in 1 12000) 36]) string?]
)]{
  Parse a C-locale number accepted by @tt{strtoflt128}, and render a quad to a
  decimal string with up to @racket[precision] significant digits. Accepted
  input includes decimal and hexadecimal floating-point syntax, signed
  infinities, and NaNs (including payload syntax). Decimal conversion is
  locale-independent and always uses @litchar{.} as the decimal separator.

  Apart from surrounding C-locale whitespace,
  @racket[string->quad-flonum] requires the entire input to be consumed as a
  valid number; malformed strings and strings with trailing nonnumeric text
  raise @racket[exn:fail:contract] instead of silently producing the value of a
  numeric prefix. A syntactically valid value outside binary128's range is not
  a parse error: overflow produces signed infinity and underflow produces signed
  zero.

  @racket[quad-flonum->string] accepts precisions from 1 through 12000 and
  sizes its output dynamically, so it returns the complete representation even
  when it is longer than a small fixed buffer. The maximum exceeds the roughly
  11,600 significant digits needed by the longest exact finite binary128
  expansion. The default of 36 is @racket[quad-decimal-dig], the number of
  digits sufficient to round-trip any finite binary128 value exactly. Textual
  NaN formatting does not preserve payload or signalling state.}

@defproc[(quad-flonum->bytes [q Quad?]) bytes?]{
  Returns the 16-byte object representation of @racket[q]'s @tt{__float128}
  value in the platform's native byte order. On x86-64 this is the value's
  little-endian byte string. The representation is platform-dependent and is
  not a portable serialization format.}

@section{IEEE 754 behavior and errors}

Arithmetic and mathematical domain errors follow GCC/libquadmath floating-point
semantics instead of raising Racket exceptions. For example, division by zero
produces signed infinity, invalid operations produce NaN, and overflow or
underflow produces infinity, subnormal values, or signed zero as appropriate.
The binding does not expose C @tt{errno} or floating-point exception flags.

NaN is unordered: every comparison involving NaN, including @racket[qf=],
returns @racket[#f]. Positive and negative zero compare equal, while
@racket[qfsignbit?] distinguishes them. @racket[qfmin] and @racket[qfmax]
follow @tt{fminq}/@tt{fmaxq}: if exactly one operand is NaN they return the
numeric operand. When both operands are zeros with different signs, the returned
zero's sign follows the libquadmath implementation; use @racket[qfcopysign] when
the sign is semantically important.

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
  logarithms (@racket[qflog1p] computes @math{log(1+x)}).
  @racket[qfexp2] is implemented as @tt{powq(2,x)}, not @tt{exp2q}.}

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
  kind, orders 0 and 1. @racket[qflgamma] returns
  @math{log(|Gamma(a)|)}; the sign reported through C's @tt{signgam} is not
  exposed.

  @bold{Concurrency note:} libquadmath's @tt{lgammaq}, which implements
  @racket[qflgamma], writes the process-global C variable @tt{signgam}. That
  makes @racket[qflgamma] unsafe to run concurrently with another
  @racket[qflgamma] call or with native code outside the package that calls
  @tt{lgammaq} or accesses @tt{signgam}. Serialize all such access at the
  application level.}

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
  multiply-add @racket[(qf+ (qf* a b) c)], computed with a single rounding where
  libquadmath provides it (see @secref["accuracy"]).}

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
  @defthing[quad-dig exact-integer?]
  @defthing[quad-decimal-dig exact-integer?]
  @defthing[quad-min-exp exact-integer?]
  @defthing[quad-max-exp exact-integer?]
  @defthing[quad-min-10-exp exact-integer?]
  @defthing[quad-max-10-exp exact-integer?]
)]{
  Format characteristics corresponding to libquadmath's @tt{FLT128_*} macros.
  @racket[quad-mant-dig] is the 113-bit significand width.
  @racket[quad-dig] is 33, the decimal precision: a decimal value with at most
  that many significant digits survives a decimal-to-binary128-to-decimal
  conversion unchanged. @racket[quad-decimal-dig] is 36, the number of digits
  sufficient for every binary128 value to survive a
  binary128-to-decimal-to-binary128 round trip. The remaining constants give
  the binary and decimal exponent ranges.}
