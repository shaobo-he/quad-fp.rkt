#lang racket/base

;; Tests for the quad-precision FFI binding. We require the *typed* module so
;; that both the untyped FFI layer (quadf.rkt) and the Typed Racket wrapper
;; (quadf-typed.rkt) are exercised in one go.

(require rackunit
         "quadf-typed.rkt")

;; Shorthands: lift a Racket double into a quad and back.
(define (qf x) (double-flonum->quad-flonum x))
(define (df q) (quad-flonum->double-flonum q))

(test-case "arithmetic"
  (check-equal? (df (qf+ (qf 1.0) (qf 1.0))) 2.0  "add")
  (check-equal? (df (qf- (qf 3.0) (qf 1.0))) 2.0  "sub")
  (check-equal? (df (qf* (qf 2.0) (qf 3.0))) 6.0  "mul")
  (check-equal? (df (qf/ (qf 6.0) (qf 2.0))) 3.0  "div"))

(test-case "abs and sqrt"
  (check-equal? (df (qfabs (qf -5.0))) 5.0 "abs of negative")
  (check-equal? (df (qfabs (qf  5.0))) 5.0 "abs of positive")
  (check-equal? (df (qfsqrt (qf 4.0))) 2.0 "sqrt 4")
  (check-equal? (df (qfsqrt (qf 9.0))) 3.0 "sqrt 9"))

(test-case "comparisons"
  (define a (qf 1.0))
  (define b (qf 2.0))
  (check-true  (qf=  a a) "= reflexive")
  (check-false (qf=  a b) "= distinct")
  (check-true  (qf<  a b) "< true")
  (check-false (qf<  b a) "< false")
  (check-false (qf<  a a) "< not reflexive")
  (check-true  (qf<= a a) "<= reflexive")
  (check-true  (qf<= a b) "<= true")
  (check-false (qf<= b a) "<= false")
  (check-true  (qf>  b a) "> true")
  (check-false (qf>  a b) "> false")
  (check-true  (qf>= a a) ">= reflexive")
  (check-true  (qf>= b a) ">= true")
  (check-false (qf>= a b) ">= false"))

(test-case "double <-> quad round-trip"
  (for ([d (in-list (list 0.0 -0.0 1.0 -1.0 0.5 -42.0 3.141592653589793 1e300 1e-300))])
    (check-equal? (df (qf d)) d (format "round-trip ~a" d))))

(test-case "quad precision exceeds double"
  ;; In double, 1.0 + 1e-20 == 1.0 (the addend falls below the ULP and is
  ;; lost). In quad there is enough mantissa to keep it, so the sum differs.
  (check-equal? (+ 1.0 1e-20) 1.0 "double loses the tiny addend")
  (define sum (qf+ (qf 1.0) (qf 1e-20)))
  (check-false (qf= sum (qf 1.0)) "quad keeps the tiny addend")
  (check-true  (qf> sum (qf 1.0)) "and the kept value is larger")

  ;; 1/3 computed in quad carries more significant digits than 1/3 computed in
  ;; double then promoted, so the two quad values are not bit-identical...
  (define third-quad (qf/ (qf 1.0) (qf 3.0)))
  (define third-dbl  (qf (/ 1.0 3.0)))
  (check-false (qf= third-quad third-dbl) "quad 1/3 differs from promoted double 1/3")
  ;; ...but they still agree to within a double's worth of precision.
  (check-true  (qf< (qfabs (qf- third-quad third-dbl)) (qf 1e-15)) "and they stay close"))

(test-case "quad-flonum->bytes"
  (check-equal? (bytes-length (quad-flonum->bytes (qf 1.0))) 16 "16 bytes wide")
  ;; 0.0 is all-zero bits regardless of endianness.
  (check-equal? (quad-flonum->bytes (qf 0.0)) (make-bytes 16 0) "zero is all-zero bits")
  ;; Equal values serialize identically; distinct values do not.
  (check-equal?    (quad-flonum->bytes (qf 1.0)) (quad-flonum->bytes (qf 1.0)) "equal -> equal bytes")
  (check-not-equal? (quad-flonum->bytes (qf 1.0)) (quad-flonum->bytes (qf 2.0)) "distinct -> distinct bytes"))
