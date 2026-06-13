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

@deftogether[(
  @defproc[(qfabs [a Quad?]) Quad?]
  @defproc[(qfsqrt [a Quad?]) Quad?]
)]{
  Absolute value and square root.}

@section{Comparison}

@deftogether[(
  @defproc[(qf= [a Quad?] [b Quad?]) boolean?]
  @defproc[(qf< [a Quad?] [b Quad?]) boolean?]
  @defproc[(qf<= [a Quad?] [b Quad?]) boolean?]
  @defproc[(qf> [a Quad?] [b Quad?]) boolean?]
  @defproc[(qf>= [a Quad?] [b Quad?]) boolean?]
)]{
  Quad-precision comparisons, returning Racket booleans.}

@section{Example}

@racketblock[
  (require quad-fp)
  (define a (double-flonum->quad-flonum 1.0))
  (define b (double-flonum->quad-flonum 1e-20))
  (code:comment "In double, 1.0 + 1e-20 == 1.0; in quad the addend survives:")
  (qf= (qf+ a b) a)
  (code:comment "=> #f")
]
