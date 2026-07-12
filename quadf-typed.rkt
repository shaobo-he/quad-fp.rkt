#lang typed/racket/base

(require/typed/provide "quadf.rkt"
                       [#:opaque Quad-Flonum Quad?]
                       ;; arithmetic
                       [qf+ (Quad-Flonum Quad-Flonum -> Quad-Flonum)]
                       [qf- (Quad-Flonum Quad-Flonum -> Quad-Flonum)]
                       [qf* (Quad-Flonum Quad-Flonum -> Quad-Flonum)]
                       [qf/ (Quad-Flonum Quad-Flonum -> Quad-Flonum)]
                       ;; unary math
                       [qfabs (Quad-Flonum -> Quad-Flonum)]
                       [qfsqrt (Quad-Flonum -> Quad-Flonum)]
                       [qfcbrt (Quad-Flonum -> Quad-Flonum)]
                       [qfsin (Quad-Flonum -> Quad-Flonum)]
                       [qfcos (Quad-Flonum -> Quad-Flonum)]
                       [qftan (Quad-Flonum -> Quad-Flonum)]
                       [qfasin (Quad-Flonum -> Quad-Flonum)]
                       [qfacos (Quad-Flonum -> Quad-Flonum)]
                       [qfatan (Quad-Flonum -> Quad-Flonum)]
                       [qfsinh (Quad-Flonum -> Quad-Flonum)]
                       [qfcosh (Quad-Flonum -> Quad-Flonum)]
                       [qftanh (Quad-Flonum -> Quad-Flonum)]
                       [qfasinh (Quad-Flonum -> Quad-Flonum)]
                       [qfacosh (Quad-Flonum -> Quad-Flonum)]
                       [qfatanh (Quad-Flonum -> Quad-Flonum)]
                       [qfexp (Quad-Flonum -> Quad-Flonum)]
                       [qfexp2 (Quad-Flonum -> Quad-Flonum)]
                       [qfexpm1 (Quad-Flonum -> Quad-Flonum)]
                       [qflog (Quad-Flonum -> Quad-Flonum)]
                       [qflog2 (Quad-Flonum -> Quad-Flonum)]
                       [qflog10 (Quad-Flonum -> Quad-Flonum)]
                       [qflog1p (Quad-Flonum -> Quad-Flonum)]
                       [qfceil (Quad-Flonum -> Quad-Flonum)]
                       [qffloor (Quad-Flonum -> Quad-Flonum)]
                       [qftrunc (Quad-Flonum -> Quad-Flonum)]
                       [qfround (Quad-Flonum -> Quad-Flonum)]
                       [qfrint (Quad-Flonum -> Quad-Flonum)]
                       [qfnearbyint (Quad-Flonum -> Quad-Flonum)]
                       [qferf (Quad-Flonum -> Quad-Flonum)]
                       [qferfc (Quad-Flonum -> Quad-Flonum)]
                       [qflgamma (Quad-Flonum -> Quad-Flonum)]
                       [qftgamma (Quad-Flonum -> Quad-Flonum)]
                       [qfj0 (Quad-Flonum -> Quad-Flonum)]
                       [qfj1 (Quad-Flonum -> Quad-Flonum)]
                       [qfy0 (Quad-Flonum -> Quad-Flonum)]
                       [qfy1 (Quad-Flonum -> Quad-Flonum)]
                       ;; binary / ternary math
                       [qfpow (Quad-Flonum Quad-Flonum -> Quad-Flonum)]
                       [qfatan2 (Quad-Flonum Quad-Flonum -> Quad-Flonum)]
                       [qfhypot (Quad-Flonum Quad-Flonum -> Quad-Flonum)]
                       [qffmod (Quad-Flonum Quad-Flonum -> Quad-Flonum)]
                       [qfremainder (Quad-Flonum Quad-Flonum -> Quad-Flonum)]
                       [qfcopysign (Quad-Flonum Quad-Flonum -> Quad-Flonum)]
                       [qffdim (Quad-Flonum Quad-Flonum -> Quad-Flonum)]
                       [qfmax (Quad-Flonum Quad-Flonum -> Quad-Flonum)]
                       [qfmin (Quad-Flonum Quad-Flonum -> Quad-Flonum)]
                       [qfnextafter (Quad-Flonum Quad-Flonum -> Quad-Flonum)]
                       [qffma (Quad-Flonum Quad-Flonum Quad-Flonum -> Quad-Flonum)]
                       ;; relations
                       [qf= (Quad-Flonum Quad-Flonum -> Boolean)]
                       [qf< (Quad-Flonum Quad-Flonum -> Boolean)]
                       [qf<= (Quad-Flonum Quad-Flonum -> Boolean)]
                       [qf> (Quad-Flonum Quad-Flonum -> Boolean)]
                       [qf>= (Quad-Flonum Quad-Flonum -> Boolean)]
                       ;; classification
                       [qfnan? (Quad-Flonum -> Boolean)]
                       [qfinfinite? (Quad-Flonum -> Boolean)]
                       [qffinite? (Quad-Flonum -> Boolean)]
                       [qfsignbit? (Quad-Flonum -> Boolean)]
                       ;; conversions
                       [double-flonum->quad-flonum (Float -> Quad-Flonum)]
                       [quad-flonum->double-flonum (Quad-Flonum -> Float)]
                       [string->quad-flonum (String -> Quad-Flonum)]
                       [quad-flonum->string (->* (Quad-Flonum) (Positive-Integer) String)]
                       ;; constants
                       [quad-pi Quad-Flonum]
                       [quad-pi/2 Quad-Flonum]
                       [quad-pi/4 Quad-Flonum]
                       [quad-1/pi Quad-Flonum]
                       [quad-2/pi Quad-Flonum]
                       [quad-2/sqrt-pi Quad-Flonum]
                       [quad-e Quad-Flonum]
                       [quad-log2e Quad-Flonum]
                       [quad-log10e Quad-Flonum]
                       [quad-ln2 Quad-Flonum]
                       [quad-ln10 Quad-Flonum]
                       [quad-sqrt2 Quad-Flonum]
                       [quad-1/sqrt2 Quad-Flonum]
                       [quad-max Quad-Flonum]
                       [quad-min Quad-Flonum]
                       [quad-epsilon Quad-Flonum]
                       [quad-denorm-min Quad-Flonum]
                       [quad-mant-dig Integer]
                       [quad-dig Integer]
                       [quad-decimal-dig Integer]
                       [quad-min-exp Integer]
                       [quad-max-exp Integer]
                       [quad-min-10-exp Integer]
                       [quad-max-10-exp Integer])

(require/typed "quadf.rkt" [Quad-fh (Quad-Flonum -> Integer)] [Quad-sh (Quad-Flonum -> Integer)])

(: quad-flonum->bytes (-> Quad-Flonum Bytes))
(define (quad-flonum->bytes x)
  (define fh (Quad-fh x))
  (define sh (Quad-sh x))
  (bytes-append (integer->integer-bytes fh 8 #f) (integer->integer-bytes sh 8 #f)))

(provide quad-flonum->bytes)
