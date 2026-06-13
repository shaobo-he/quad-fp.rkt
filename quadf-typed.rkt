#lang typed/racket/base

(require/typed/provide
 "quadf.rkt"
 [#:opaque Quad-Flonum Quad?]
 [qf+ (Quad-Flonum Quad-Flonum -> Quad-Flonum)]
 [qf- (Quad-Flonum Quad-Flonum -> Quad-Flonum)]
 [qf* (Quad-Flonum Quad-Flonum -> Quad-Flonum)]
 [qf/ (Quad-Flonum Quad-Flonum -> Quad-Flonum)]
 [qfabs (Quad-Flonum -> Quad-Flonum)]
 [qfsqrt (Quad-Flonum -> Quad-Flonum)]
 [qf= (Quad-Flonum Quad-Flonum -> Boolean)]
 [qf< (Quad-Flonum Quad-Flonum -> Boolean)]
 [qf<= (Quad-Flonum Quad-Flonum -> Boolean)]
 [qf> (Quad-Flonum Quad-Flonum -> Boolean)]
 [qf>= (Quad-Flonum Quad-Flonum -> Boolean)]
 [double-flonum->quad-flonum (Float -> Quad-Flonum)]
 [quad-flonum->double-flonum (Quad-Flonum -> Float)])

(require/typed
 "quadf.rkt"
 [Quad-fh (Quad-Flonum -> Integer)]
 [Quad-sh (Quad-Flonum -> Integer)])

(: quad-flonum->bytes (-> Quad-Flonum Bytes))
(define (quad-flonum->bytes x)
  (define fh (Quad-fh x))
  (define sh (Quad-sh x))
  (bytes-append
   (integer->integer-bytes fh 8 #f)
   (integer->integer-bytes sh 8 #f)))

(provide quad-flonum->bytes)

