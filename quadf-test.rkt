#lang racket/base

;; Tests for the quad-precision FFI binding. They live in a `test` submodule so
;; rackunit stays a build-time dependency. We require the *typed* module so that
;; both the untyped FFI layer (quadf.rkt) and the Typed Racket wrapper
;; (quadf-typed.rkt) are exercised in one go.

(module+ test
  (require rackunit
           "quadf-typed.rkt")

  ;; Shorthands: lift a Racket double into a quad and back.
  (define (qf x)
    (double-flonum->quad-flonum x))
  (define (df q)
    (quad-flonum->double-flonum q))

  ;; Approximate equality, for results that aren't bit-exact (transcendentals
  ;; aren't guaranteed correctly-rounded). Tolerance is a few dozen quad ULPs.
  (define (qclose? a b)
    (qf< (qfabs (qf- a b)) (qf* quad-epsilon (qf 64.0))))

  (test-case "arithmetic"
    (check-equal? (df (qf+ (qf 1.0) (qf 1.0))) 2.0 "add")
    (check-equal? (df (qf- (qf 3.0) (qf 1.0))) 2.0 "sub")
    (check-equal? (df (qf* (qf 2.0) (qf 3.0))) 6.0 "mul")
    (check-equal? (df (qf/ (qf 6.0) (qf 2.0))) 3.0 "div"))

  (test-case "unary math"
    (check-equal? (df (qfabs (qf -5.0))) 5.0 "abs")
    (check-equal? (df (qfsqrt (qf 9.0))) 3.0 "sqrt")
    (check-equal? (df (qfcbrt (qf 27.0))) 3.0 "cbrt")
    (check-equal? (df (qfsin (qf 0.0))) 0.0 "sin 0")
    (check-equal? (df (qfcos (qf 0.0))) 1.0 "cos 0")
    (check-equal? (df (qftan (qf 0.0))) 0.0 "tan 0")
    (check-equal? (df (qfexp (qf 0.0))) 1.0 "exp 0")
    (check-equal? (df (qflog (qf 1.0))) 0.0 "log 1")
    (check-equal? (df (qflog2 (qf 8.0))) 3.0 "log2 8")
    (check-equal? (df (qflog10 (qf 1000.0))) 3.0 "log10 1000")
    (check-equal? (df (qferf (qf 0.0))) 0.0 "erf 0")
    (check-equal? (df (qferfc (qf 0.0))) 1.0 "erfc 0")
    (check-equal? (df (qftgamma (qf 5.0))) 24.0 "tgamma 5 = 4!")
    (check-equal? (df (qffloor (qf 2.7))) 2.0 "floor")
    (check-equal? (df (qfceil (qf 2.1))) 3.0 "ceil")
    (check-equal? (df (qftrunc (qf -2.7))) -2.0 "trunc")
    (check-equal? (df (qfround (qf 2.5))) 3.0 "round half away")
    (check-true (qclose? (qfasin (qfsin (qf 0.5))) (qf 0.5)) "asin∘sin")
    (check-true (qclose? (qfatanh (qftanh (qf 0.5))) (qf 0.5)) "atanh∘tanh"))

  (test-case "binary and ternary math"
    (check-equal? (df (qfpow (qf 2.0) (qf 10.0))) 1024.0 "pow")
    (check-equal? (df (qfhypot (qf 3.0) (qf 4.0))) 5.0 "hypot")
    (check-equal? (df (qffmod (qf 7.0) (qf 3.0))) 1.0 "fmod")
    (check-equal? (df (qfcopysign (qf 3.0) (qf -1.0))) -3.0 "copysign")
    (check-equal? (df (qfmax (qf 2.0) (qf 5.0))) 5.0 "max")
    (check-equal? (df (qfmin (qf 2.0) (qf 5.0))) 2.0 "min")
    (check-equal? (df (qffdim (qf 5.0) (qf 3.0))) 2.0 "fdim positive")
    (check-equal? (df (qffdim (qf 3.0) (qf 5.0))) 0.0 "fdim clamped")
    (check-equal? (df (qfatan2 (qf 0.0) (qf 1.0))) 0.0 "atan2")
    (check-equal? (df (qffma (qf 2.0) (qf 3.0) (qf 4.0))) 10.0 "fma = a*b+c"))

  (test-case "comparisons"
    (define a (qf 1.0))
    (define b (qf 2.0))
    (check-true (qf= a a) "= reflexive")
    (check-false (qf= a b) "= distinct")
    (check-true (qf< a b) "< true")
    (check-false (qf< a a) "< not reflexive")
    (check-true (qf<= a a) "<= reflexive")
    (check-true (qf> b a) "> true")
    (check-true (qf>= a a) ">= reflexive")
    (check-false (qf>= a b) ">= false"))

  (test-case "classification"
    (define nan (qf/ (qf 0.0) (qf 0.0)))
    (define inf (qf/ (qf 1.0) (qf 0.0)))
    (check-true (qfnan? nan) "nan? of 0/0")
    (check-false (qfnan? (qf 1.0)) "nan? of finite")
    (check-true (qfinfinite? inf) "infinite? of 1/0")
    (check-false (qfinfinite? (qf 1.0)) "infinite? of finite")
    (check-true (qffinite? (qf 1.0)) "finite? of finite")
    (check-false (qffinite? inf) "finite? of inf")
    (check-true (qfsignbit? (qf -1.0)) "signbit of negative")
    (check-false (qfsignbit? (qf 1.0)) "signbit of positive"))

  (test-case "double <-> quad round-trip"
    (for ([d (in-list (list 0.0 -0.0 1.0 -1.0 0.5 -42.0 3.141592653589793 1e300 1e-300))])
      (check-equal? (df (qf d)) d (format "round-trip ~a" d))))

  (test-case "string <-> quad"
    (check-true (qf= (string->quad-flonum "2") (qf 2.0)) "parse integer")
    (check-true (qf= (string->quad-flonum "1.5") (qf 1.5)) "parse decimal")
    ;; 36 significant digits round-trips binary128 exactly.
    (check-true (qf= quad-pi (string->quad-flonum (quad-flonum->string quad-pi)))
                "string round-trip is exact")
    (check-true (string? (quad-flonum->string (qf 1.0) 5)) "precision arg accepted"))

  (test-case "constants"
    (check-equal? quad-mant-dig 113 "binary128 mantissa bits")
    (check-equal? quad-decimal-dig 33 "round-trippable decimal digits")
    ;; sqrt is correctly rounded, so the parsed constant is bit-exact.
    (check-true (qf= quad-sqrt2 (qfsqrt (qf 2.0))) "sqrt2 constant")
    (check-true (qclose? quad-pi (qf* (qf 4.0) (qfatan (qf 1.0)))) "pi ≈ 4·atan(1)")
    (check-true (qclose? quad-e (qfexp (qf 1.0))) "e ≈ exp(1)")
    (check-true (qffinite? quad-max) "FLT128_MAX is finite")
    (check-true (qf> quad-max (qf 1e300)) "FLT128_MAX is huge")
    (check-true (qfinfinite? (qf* quad-max (qf 2.0))) "overflow past FLT128_MAX → inf"))

  (test-case "quad precision exceeds double"
    ;; In double, 1.0 + 1e-20 == 1.0 (the addend falls below the ULP and is
    ;; lost). In quad there is enough mantissa to keep it, so the sum differs.
    (check-equal? (+ 1.0 1e-20) 1.0 "double loses the tiny addend")
    (define sum (qf+ (qf 1.0) (qf 1e-20)))
    (check-false (qf= sum (qf 1.0)) "quad keeps the tiny addend")
    (check-true (qf> sum (qf 1.0)) "and the kept value is larger"))

  (test-case "quad-flonum->bytes"
    (check-equal? (bytes-length (quad-flonum->bytes (qf 1.0))) 16 "16 bytes wide")
    ;; 0.0 is all-zero bits regardless of endianness.
    (check-equal? (quad-flonum->bytes (qf 0.0)) (make-bytes 16 0) "zero is all-zero bits")
    (check-not-equal? (quad-flonum->bytes (qf 1.0))
                      (quad-flonum->bytes (qf 2.0))
                      "distinct -> distinct bytes")))
