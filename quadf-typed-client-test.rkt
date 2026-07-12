#lang typed/racket/base

;; Compile and execute a real Typed Racket consumer of the public collection
;; entry point. This catches accidental loss of the opaque type information
;; through main.rkt's re-export layer.

(require typed/rackunit
         quad-fp)

(: square (Quad-Flonum -> Quad-Flonum))
(define (square x)
  (qf* x x))

(module+ test
  (define x : Quad-Flonum (string->quad-flonum "1.25"))
  (define x² : Quad-Flonum (square x))
  (check-equal? (quad-flonum->string x²) "1.5625")
  (check-true (qf= (qfsqrt x²) x))
  (check-equal? (bytes-length (quad-flonum->bytes x)) 16)
  (check-equal? quad-mant-dig 113)
  (check-equal? (quad-flonum->string quad-pi 36)
                "3.1415926535897932384626433832795028"))
