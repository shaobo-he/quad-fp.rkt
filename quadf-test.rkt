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
  (define (word->native-bytes n)
    (integer->integer-bytes n 8 #f (system-big-endian?)))
  (define (binary128->native-bytes high low)
    (if (system-big-endian?)
        (bytes-append (word->native-bytes high) (word->native-bytes low))
        (bytes-append (word->native-bytes low) (word->native-bytes high))))

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
    (check-equal? (df (qfexp2 (qf 10.0))) 1024.0 "exp2 10 (via powq)")
    (check-equal? (df (qferf (qf 0.0))) 0.0 "erf 0")
    (check-equal? (df (qferfc (qf 0.0))) 1.0 "erfc 0")
    (check-equal? (df (qftgamma (qf 5.0))) 24.0 "tgamma 5 = 4!")
    (check-equal? (df (qffloor (qf 2.7))) 2.0 "floor")
    (check-equal? (df (qfceil (qf 2.1))) 3.0 "ceil")
    (check-equal? (df (qftrunc (qf -2.7))) -2.0 "trunc")
    (check-equal? (df (qfround (qf 2.5))) 3.0 "round half away")
    (check-equal? (df (qfrint (qf 2.5))) 2.0 "rint ties to even in the default mode")
    (check-equal? (df (qfnearbyint (qf 2.5))) 2.0 "nearbyint uses the default mode")
    (check-true (qclose? (qfasin (qfsin (qf 0.5))) (qf 0.5)) "asin∘sin")
    (check-true (qclose? (qfatanh (qftanh (qf 0.5))) (qf 0.5)) "atanh∘tanh"))

  (test-case "Bessel bindings"
    (check-equal? (df (qfj0 (qf 0.0))) 1.0 "j0(0)")
    (check-equal? (df (qfj1 (qf 0.0))) 0.0 "j1(0)")
    (check-= (df (qfy0 (qf 1.0))) 0.08825696421567696 1e-15 "y0(1)")
    (check-= (df (qfy1 (qf 1.0))) -0.7812128213002887 1e-15 "y1(1)"))

  (test-case "binary and ternary math"
    (check-equal? (df (qfpow (qf 2.0) (qf 10.0))) 1024.0 "pow")
    (check-equal? (df (qfhypot (qf 3.0) (qf 4.0))) 5.0 "hypot")
    (check-equal? (df (qffmod (qf 7.0) (qf 3.0))) 1.0 "fmod")
    (check-equal? (df (qffmod (qf 7.0) (qf 4.0))) 3.0 "fmod truncates the quotient")
    (check-equal? (df (qfremainder (qf 7.0) (qf 4.0))) -1.0 "remainder rounds the quotient")
    (check-equal? (df (qfcopysign (qf 3.0) (qf -1.0))) -3.0 "copysign")
    (check-equal? (df (qfmax (qf 2.0) (qf 5.0))) 5.0 "max")
    (check-equal? (df (qfmin (qf 2.0) (qf 5.0))) 2.0 "min")
    (check-equal? (df (qffdim (qf 5.0) (qf 3.0))) 2.0 "fdim positive")
    (check-equal? (df (qffdim (qf 3.0) (qf 5.0))) 0.0 "fdim clamped")
    (check-equal? (df (qfatan2 (qf 0.0) (qf 1.0))) 0.0 "atan2")
    (check-equal? (df (qffma (qf 2.0) (qf 3.0) (qf 4.0))) 10.0 "fma = a*b+c")
    ;; This vector rounds the product to 1 before a separate subtraction, but
    ;; the exact product-minus-one is positive and survives a fused operation.
    (define one (qf 1.0))
    (define up (qfnextafter one (qf 2.0)))
    (define down (qfnextafter one (qf 0.0)))
    (check-true (qf= (qf- (qf* up down) one) (qf 0.0)) "separate multiply rounds away residue")
    (define fused-residue (qffma up down (qf -1.0)))
    (check-true (qf> fused-residue (qf 0.0)) "fma retains the cancellation residue"))

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

  (test-case "IEEE special values"
    (define zero (qf 0.0))
    (define negative-zero (string->quad-flonum "-0"))
    (define one (qf 1.0))
    (define nan (string->quad-flonum "nan"))
    (define positive-infinity (string->quad-flonum "inf"))
    (define negative-infinity (string->quad-flonum "-inf"))
    (check-true (qf= zero negative-zero) "signed zeros compare equal")
    (check-true (qfsignbit? negative-zero) "negative zero retains its sign")
    (for ([relation (in-list (list qf= qf< qf<= qf> qf>=))])
      (check-false (relation nan one) "NaN is unordered"))
    (check-true (qf= (qfmax nan one) one) "fmax ignores one NaN")
    (check-true (qf= (qfmin nan one) one) "fmin ignores one NaN")
    (check-true (qf= (qfmax zero negative-zero) zero) "fmax returns a zero")
    (check-true (qf= (qfmin zero negative-zero) zero) "fmin returns a zero")
    (check-true (qfsignbit? (qfcopysign zero (qf -1.0))) "copysign creates negative zero")
    (check-true (qf= (qfnextafter zero one) quad-denorm-min) "nextafter reaches min subnormal")
    (check-true (qfinfinite? (qfnextafter quad-max positive-infinity)) "nextafter overflows max")
    (check-true (qfinfinite? (qf/ one negative-zero)) "division by negative zero is infinite")
    (check-true (qfsignbit? (qf/ one negative-zero)) "division preserves the zero sign")
    (check-true (qf< negative-infinity positive-infinity) "signed infinities are ordered"))

  (test-case "double <-> quad round-trip"
    (for ([d (in-list (list 0.0 -0.0 1.0 -1.0 0.5 -42.0 3.141592653589793 1e300 1e-300))])
      (check-equal? (df (qf d)) d (format "round-trip ~a" d))))

  (test-case "string <-> quad"
    (check-true (qf= (string->quad-flonum "2") (qf 2.0)) "parse integer")
    (check-true (qf= (string->quad-flonum "1.5") (qf 1.5)) "parse decimal")
    (check-true (qf= (string->quad-flonum " \t1.5\r\n") (qf 1.5))
                "surrounding C-locale whitespace is accepted")
    (check-equal? (quad-flonum->string (string->quad-flonum "1.5") 5)
                  "1.5"
                  "conversion always uses a dot decimal separator")
    (check-true (qf= (string->quad-flonum "0x1p+2") (qf 4.0)) "hexadecimal syntax")
    (check-true (qfinfinite? (string->quad-flonum "1e99999")) "overflow produces infinity")
    (check-true (qf= (string->quad-flonum "1e-99999") (qf 0.0)) "underflow produces zero")
    (check-true (qfnan? (string->quad-flonum "nan(payload)")) "NaN payload syntax")
    (for ([bad (in-list (list "" " " "not-a-number" "1.25junk" "1 2" "1\0.25"))])
      (check-exn #rx"exactly one quad-precision number"
                 (lambda () (string->quad-flonum bad))
                 (format "reject malformed input ~s" bad)))
    ;; 36 significant digits round-trips binary128 exactly.
    (check-true (qf= quad-pi (string->quad-flonum (quad-flonum->string quad-pi)))
                "string round-trip is exact")
    (check-true (string? (quad-flonum->string (qf 1.0) 5)) "precision arg accepted")
    ;; The smallest subnormal exercises both the maximum supported precision
    ;; and the retry path beyond the formatter's initial 128-byte buffer.
    (define exact-denorm (quad-flonum->string quad-denorm-min 12000))
    (check-true (> (string-length exact-denorm) 11000)
                "high precision output is not truncated")
    (check-true (qf= quad-denorm-min (string->quad-flonum exact-denorm))
                "high precision output round-trips")
    (for ([bad-precision (in-list (list 0 -1 12001 (expt 2 100) 1/2))])
      (check-exn exn:fail:contract?
                 (lambda () (quad-flonum->string quad-pi bad-precision))
                 (format "reject precision ~s" bad-precision))))

  (test-case "constants"
    (check-equal? quad-mant-dig 113 "binary128 mantissa bits")
    (check-equal? quad-dig 33 "decimal source digits preserved by binary128")
    (check-equal? quad-decimal-dig 36 "digits sufficient to round-trip binary128")
    (check-equal? quad-min-exp -16381)
    (check-equal? quad-max-exp 16384)
    (check-equal? quad-min-10-exp -4931)
    (check-equal? quad-max-10-exp 4932)
    (define next-one (qfnextafter (qf 1.0) (qf 2.0)))
    (check-false
     (qf= next-one
          (string->quad-flonum (quad-flonum->string next-one quad-dig)))
     "FLT128_DIG is not a binary128-to-decimal round-trip guarantee")
    (check-true
     (qf= next-one
          (string->quad-flonum (quad-flonum->string next-one quad-decimal-dig)))
     "FLT128_DECIMAL_DIG round-trips binary128")
    ;; sqrt is correctly rounded on recent libquadmath, faithfully rounded on
    ;; older builds — so compare the parsed constant to within a few ULP.
    (check-true (qclose? quad-sqrt2 (qfsqrt (qf 2.0))) "sqrt2 constant")
    (check-true (qclose? quad-pi (qf* (qf 4.0) (qfatan (qf 1.0)))) "pi ≈ 4·atan(1)")
    (check-true (qclose? quad-e (qfexp (qf 1.0))) "e ≈ exp(1)")
    (check-true (qf= (qf* quad-pi/2 (qf 2.0)) quad-pi) "pi/2 scales exactly")
    (check-true (qf= (qf* quad-pi/4 (qf 4.0)) quad-pi) "pi/4 scales exactly")
    (check-true (qclose? (qf* quad-1/pi quad-pi) (qf 1.0)) "(1/pi)*pi")
    (check-true (qclose? (qf* quad-2/pi quad-pi) (qf 2.0)) "(2/pi)*pi")
    (check-true (qclose? (qf* quad-2/sqrt-pi (qfsqrt quad-pi)) (qf 2.0)) "2/sqrt(pi)")
    (check-true (qclose? (qf* quad-log2e quad-ln2) (qf 1.0)) "log2(e)*ln(2)")
    (check-true (qclose? (qf* quad-log10e quad-ln10) (qf 1.0)) "log10(e)*ln(10)")
    (check-true (qclose? (qf* quad-sqrt2 quad-1/sqrt2) (qf 1.0)) "sqrt2 reciprocal")
    (check-true (qf> (qf+ (qf 1.0) quad-epsilon) (qf 1.0)) "epsilon advances 1")
    (check-true
     (qf= (qf+ (qf 1.0) (qf/ quad-epsilon (qf 2.0))) (qf 1.0))
     "half epsilon ties back to even")
    (check-true (qf> quad-min quad-denorm-min) "normal minimum exceeds subnormal minimum")
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
                      "distinct -> distinct bytes")
    (check-equal?
     (quad-flonum->bytes (qf 1.0))
     (binary128->native-bytes #x3fff000000000000 0)
     "1.0 has the IEEE binary128 encoding")
    (check-equal?
     (quad-flonum->bytes (string->quad-flonum "-0"))
     (binary128->native-bytes #x8000000000000000 0)
     "-0 has only the sign bit set")
    (check-equal?
     (quad-flonum->bytes (string->quad-flonum "inf"))
     (binary128->native-bytes #x7fff000000000000 0)
     "infinity has the IEEE binary128 encoding")
    (check-equal?
     (quad-flonum->bytes (qfnextafter (qf 1.0) (qf 2.0)))
     (binary128->native-bytes #x3fff000000000000 1)
     "nextafter increments the low significand word")))
