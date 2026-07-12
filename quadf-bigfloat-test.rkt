#lang racket/base

;; Property-based tests (rackcheck) that check the quad ops against
;; `math/bigfloat` at 113-bit precision — i.e. the binary128 significand width.
;;
;; The split matters: `+ - * /` are correctly rounded on every libquadmath, so
;; they must match bigfloat *bit for bit*. `sqrt`, `fma`, and the
;; transcendentals are only correctly rounded on recent builds, so they are held
;; to ULP bounds sized for the oldest libquadmath we expect to run on (the
;; package server's natipkg toolchain). See the tolerance definitions below for
;; the per-operation rationale and the measured figures behind each bound.
;;
;; Lives in a `test` submodule so rackcheck-lib and math-lib stay build-time
;; dependencies.

(module+ test
  (require rackcheck
           rackunit
           math/bigfloat
           "quadf-typed.rkt")

  (bf-precision 113) ; binary128 significand width

  (define (environment-integer name default minimum)
    (define text (getenv name))
    (define value (and text (string->number text)))
    (cond
      [(not text) default]
      [(and (exact-integer? value) (>= value minimum)) value]
      [else
       (error 'quadf-bigfloat-test
              "~a must be an exact integer >= ~a; received ~e"
              name
              minimum
              text)]))

  (define property-test-count (environment-integer "RACKCHECK_TESTS" 10000 1))
  (define property-seed (environment-integer "RACKCHECK_SEED" 1337 0))
  (define cfg (make-config #:tests property-test-count #:seed property-seed))
  (define edge-cfg
    (make-config #:tests (max 100 (quotient property-test-count 5)) #:seed (add1 property-seed)))
  (printf "quad-fp property configuration: tests=~a seed=~a edge-tests=~a\n"
          property-test-count
          property-seed
          (max 100 (quotient property-test-count 5)))

  ;; --- bridge: a quad and a bigfloat denoting the same binary128 value -----
  ;; quad -> bigfloat is exact: 36 significant digits round-trips binary128.
  (define (q->bf q)
    (bf (quad-flonum->string q)))
  (define (bf->q b)
    (string->quad-flonum (bigfloat->string b)))
  (define (bytes->nat bs)
    (for/fold ([n 0]) ([b (in-bytes bs)])
      (+ (* n 256) b)))
  (define (2^ n)
    (bfexpt (bf 2) (bf n)))

  ;; Generator of (cons quad bigfloat) with identical value. The mantissa is
  ;; drawn from random bytes (full 113-bit coverage); magnitude is log-uniform
  ;; across [2^emin, 2^emax).
  (define (gen:val #:emin [emin -100] #:emax [emax 100] #:sign [sign 'both])
    (gen:let ([bs (gen:bytes)] [e (gen:integer-in emin emax)] [neg gen:boolean])
             (define len (max 1 (bytes-length bs)))
             (define frac (bf/ (bf (bytes->nat bs)) (2^ (* 8 len)))) ; [0,1)
             (define mag (bf* (bf+ (bf 1) frac) (2^ e))) ; [2^e, 2^(e+1))
             (define b
               (if (and (eq? sign 'both) neg)
                   (bf- mag)
                   mag))
             (define q (bf->q b))
             ;; Anchor the reference to the parsed binary128 input. This keeps
             ;; the pair identical even in the subnormal range.
             (cons q (q->bf q))))

  ;; Generator of values spread linearly across [lo, hi] (bounded domains).
  (define (gen:val-in lo hi)
    (gen:let ([bs (gen:bytes)])
             (define len (max 1 (bytes-length bs)))
             (define frac (bf/ (bf (bytes->nat bs)) (2^ (* 8 len)))) ; [0,1)
             (define b (bf+ (bf lo) (bf* (bf- (bf hi) (bf lo)) frac)))
             (define q (bf->q b))
             (cons q (q->bf q))))

  ;; --- comparison ----------------------------------------------------------
  (define (exact? q-result bf-result)
    (bf= (q->bf q-result) bf-result))

  ;; Round an exact rational to an IEEE 754 binary128 object representation.
  ;; Using integers here avoids a second MPFR or decimal rounding at the
  ;; subnormal and overflow boundaries that these tests are meant to probe.
  (define binary128-fraction-bits 112)
  (define binary128-bias 16383)
  (define binary128-min-exponent -16382)
  (define binary128-max-exponent 16383)
  (define binary128-min-subnormal-exponent -16494)
  (define binary128-significand-limit (expt 2 binary128-fraction-bits))
  (define binary128-infinity-bits (arithmetic-shift #x7fff binary128-fraction-bits))
  (define binary128-sign-bit (arithmetic-shift 1 127))
  (define binary128-low-word-mask (sub1 (expt 2 64)))

  (define (round-rational-to-even x)
    (define-values (integer-part remainder)
      (quotient/remainder (numerator x) (denominator x)))
    (define doubled-remainder (* 2 remainder))
    (cond
      [(< doubled-remainder (denominator x)) integer-part]
      [(> doubled-remainder (denominator x)) (add1 integer-part)]
      [(even? integer-part) integer-part]
      [else (add1 integer-part)]))

  (define (floor-log2-rational x)
    (define tentative
      (- (integer-length (numerator x)) (integer-length (denominator x))))
    (if (>= x (expt 2 tentative)) tentative (sub1 tentative)))

  (define (rational->binary128-bits x)
    (define negative-value? (negative? x))
    (define magnitude (abs x))
    (define sign-bits (if negative-value? binary128-sign-bit 0))
    (define magnitude-bits
      (cond
        [(zero? magnitude) 0]
        [else
         (define exponent (floor-log2-rational magnitude))
         (cond
           [(< exponent binary128-min-exponent)
            ;; Subnormals use a fixed 2^-16494 quantum. A rounded significand
            ;; of 2^112 is exactly the minimum normal encoding.
            (round-rational-to-even
             (* magnitude (expt 2 (- binary128-min-subnormal-exponent))))]
           [(> exponent binary128-max-exponent) binary128-infinity-bits]
           [else
            (define significand
              (round-rational-to-even
               (* magnitude (expt 2 (- binary128-fraction-bits exponent)))))
            (define carry? (= significand (* 2 binary128-significand-limit)))
            (define rounded-exponent (if carry? (add1 exponent) exponent))
            (define rounded-significand
              (if carry? binary128-significand-limit significand))
            (if (> rounded-exponent binary128-max-exponent)
                binary128-infinity-bits
                (+ (arithmetic-shift (+ rounded-exponent binary128-bias)
                                     binary128-fraction-bits)
                   (- rounded-significand binary128-significand-limit)))])]))
    (bitwise-ior sign-bits magnitude-bits))

  (define (exact-binary128? q-result rational-result)
    (define bits (rational->binary128-bits rational-result))
    (define low-bytes
      (integer->integer-bytes
       (bitwise-and bits binary128-low-word-mask) 8 #f (system-big-endian?)))
    (define high-bytes
      (integer->integer-bytes (arithmetic-shift bits -64) 8 #f (system-big-endian?)))
    (define expected
      (if (system-big-endian?)
          (bytes-append high-bytes low-bytes)
          (bytes-append low-bytes high-bytes)))
    (bytes=? (quad-flonum->bytes q-result) expected))

  (test-case "exact-rational binary128 oracle"
    (check-equal? (rational->binary128-bits 0) 0)
    (check-equal? (rational->binary128-bits 1)
                  (arithmetic-shift #x3fff binary128-fraction-bits))
    (check-equal? (rational->binary128-bits (expt 2 binary128-min-subnormal-exponent)) 1)
    (check-equal? (rational->binary128-bits (expt 2 (sub1 binary128-min-subnormal-exponent)))
                  0
                  "half the minimum subnormal ties to even zero")
    (define max-finite
      (* (sub1 (* 2 binary128-significand-limit)) (expt 2 16271)))
    (check-equal? (rational->binary128-bits max-finite)
                  (sub1 binary128-infinity-bits))
    (check-equal? (rational->binary128-bits (+ max-finite (expt 2 16270)))
                  binary128-infinity-bits
                  "the overflow midpoint rounds to infinity"))

  ;; Relative tolerances. Across a normalized binary128 binade, one ULP ranges
  ;; from 2^-112 to just over 2^-113 of the value, so a fixed relative bound
  ;; corresponds to a factor-of-two range of ULP counts. The bounds looser than
  ;; "exact" accommodate older libquadmath builds (e.g. the package server's):
  ;;   sqrt  — without soft-fp, sqrtq refines a (double)sqrt seed with Newton
  ;;           steps and no final correcting rounding, so it is faithfully
  ;;           (<=1 ULP), not correctly, rounded; recent builds round correctly
  ;;           (Innocente-Zimmermann measure binary128 sqrt at 0.5 ULP).
  ;;   fma   — older fmaq is a true (Dekker/Knuth, cancellation-safe) fma but
  ;;           lacks the round-to-odd step, so it can double-round by <=1 ULP.
  ;;   gamma — tgammaq varies most by version: glibc's binary128 tgamma peaks
  ;;           near 11 ULP, but the server's older libquadmath exceeds 64 ULP.
  ;;           A 2^-90 relative bound still pins ~27 correct digits — enough to
  ;;           catch a mis-bound function, bad marshalling, or a wrong scale.
  (define TOL-RND (2^ -110)) ; ~4–8 ULP — near-correctly-rounded (sqrt, fma)
  (define TOL (2^ -106)) ;      ~64–128 ULP — transcendentals
  (define TOL-GAMMA (2^ -90)) ; ~4–8M ULP — gamma (version-dependent; see above)
  (define (approx? q-result bf-result [tol TOL])
    (define got (q->bf q-result))
    (if (bfzero? bf-result)
        (bf<= (bfabs got) tol)
        (bf<= (bfabs (bf/ (bf- got bf-result) bf-result)) tol)))

  ;; --- core ops vs bigfloat ------------------------------------------------
  ;; +, -, *, /, abs are correctly rounded everywhere → bit-exact. sqrt and fma
  ;; are bit-exact on recent libquadmath but only faithfully rounded on older
  ;; builds, so they get a few-ULP bound (TOL-RND) instead of exact equality.
  (test-case "qf+ = bf+"
    (check-property cfg
                    (property ([a (gen:val)] [b (gen:val)])
                              (exact? (qf+ (car a) (car b)) (bf+ (cdr a) (cdr b))))))
  (test-case "qf- = bf-"
    (check-property cfg
                    (property ([a (gen:val)] [b (gen:val)])
                              (exact? (qf- (car a) (car b)) (bf- (cdr a) (cdr b))))))
  (test-case "qf* = bf*"
    (check-property cfg
                    (property ([a (gen:val)] [b (gen:val)])
                              (exact? (qf* (car a) (car b)) (bf* (cdr a) (cdr b))))))
  (test-case "qf/ = bf/"
    (check-property cfg
                    (property ([a (gen:val)] [b (gen:val)])
                              (exact? (qf/ (car a) (car b)) (bf/ (cdr a) (cdr b))))))
  (test-case "qfsqrt ~ bfsqrt (relative error <= 2^-110; often bit-exact)"
    (check-property cfg
                    (property ([a (gen:val #:sign 'nonneg)])
                              (approx? (qfsqrt (car a)) (bfsqrt (cdr a)) TOL-RND))))
  (test-case "qfabs = bfabs"
    (check-property cfg (property ([a (gen:val)]) (exact? (qfabs (car a)) (bfabs (cdr a))))))

  ;; Exercise the exponent boundaries that the ordinary [-100, 100] generator
  ;; intentionally avoids. Exact rational arithmetic supplies an independent
  ;; oracle for binary128's gradual underflow and overflow rounding.
  (define gen:tiny (gen:val #:emin -16494 #:emax -16380))
  (define gen:huge (gen:val #:emin 16300 #:emax 16382))
  (define boundary-regions
    (list (list "at the subnormal boundary" gen:tiny)
          (list "near overflow" gen:huge)))
  (define exact-arithmetic-operations
    (list (list "+" qf+ +)
          (list "-" qf- -)
          (list "*" qf* *)
          (list "/" qf/ /)))
  (for* ([region (in-list boundary-regions)]
         [operation (in-list exact-arithmetic-operations)])
    (define region-name (car region))
    (define generator (cadr region))
    (define operation-name (car operation))
    (define quad-operation (cadr operation))
    (define rational-operation (caddr operation))
    (test-case (format "qf~a agrees ~a" operation-name region-name)
      (check-property
       edge-cfg
       (property ([a generator] [b generator])
         (exact-binary128?
          (quad-operation (car a) (car b))
          (rational-operation (bigfloat->rational (cdr a))
                              (bigfloat->rational (cdr b))))))))
  (test-case "qffma ~ round(a*b+c) with relative error <= 2^-110"
    (check-property cfg
                    (property ([a (gen:val #:emin -40 #:emax 40)] [b (gen:val #:emin -40 #:emax 40)]
                                                                  [c (gen:val #:emin -40 #:emax 40)])
                              ;; reference fused multiply-add: a*b+c exact (500 bits), then
                              ;; one rounding to 113 bits.
                              (define ref
                                (parameterize ([bf-precision 113])
                                  (bf+ (parameterize ([bf-precision 500])
                                         (bf+ (bf* (cdr a) (cdr b)) (cdr c)))
                                       (bf 0))))
                              (approx? (qffma (car a) (car b) (car c)) ref TOL-RND))))

  ;; --- relations agree with bigfloat ---------------------------------------
  (test-case "comparisons agree with bigfloat"
    (check-property cfg
                    (property ([a (gen:val)] [b (gen:val)])
                              (define x (cdr a))
                              (define y (cdr b))
                              (and (eq? (qf< (car a) (car b)) (bf< x y))
                                   (eq? (qf<= (car a) (car b)) (bf<= x y))
                                   (eq? (qf> (car a) (car b)) (bf> x y))
                                   (eq? (qf>= (car a) (car b)) (bf>= x y))
                                   (eq? (qf= (car a) (car b)) (bf= x y))))))

  ;; --- approx: transcendentals within 2^-106 relative error of bigfloat -----
  ;; Each row: name, our op, bigfloat op, input generator (domain-appropriate).
  (define unary-approx
    (list (list "exp" qfexp bfexp (gen:val #:emin -6 #:emax 6))
          (list "exp2" qfexp2 bfexp2 (gen:val #:emin -6 #:emax 6))
          (list "expm1" qfexpm1 bfexpm1 (gen:val #:emin -6 #:emax 6))
          (list "sinh" qfsinh bfsinh (gen:val #:emin -6 #:emax 6))
          (list "cosh" qfcosh bfcosh (gen:val #:emin -6 #:emax 6))
          (list "tanh" qftanh bftanh (gen:val #:emin -6 #:emax 6))
          (list "sin" qfsin bfsin (gen:val #:emin -6 #:emax 6))
          (list "cos" qfcos bfcos (gen:val #:emin -6 #:emax 6))
          (list "tan" qftan bftan (gen:val #:emin -6 #:emax 3))
          (list "atan" qfatan bfatan (gen:val #:emin -10 #:emax 20))
          (list "asinh" qfasinh bfasinh (gen:val #:emin -10 #:emax 20))
          (list "cbrt" qfcbrt bfcbrt (gen:val))
          (list "erf" qferf bferf (gen:val #:emin -6 #:emax 3))
          (list "erfc" qferfc bferfc (gen:val #:emin -3 #:emax 3))
          (list "log" qflog bflog (gen:val #:emin -80 #:emax 80 #:sign 'nonneg))
          (list "log2" qflog2 bflog2 (gen:val #:emin -80 #:emax 80 #:sign 'nonneg))
          (list "log10" qflog10 bflog10 (gen:val #:emin -80 #:emax 80 #:sign 'nonneg))
          (list "asin" qfasin bfasin (gen:val-in -1 1))
          (list "acos" qfacos bfacos (gen:val-in -1 1))
          (list "atanh" qfatanh bfatanh (gen:val-in -3/4 3/4))
          (list "acosh" qfacosh bfacosh (gen:val-in 1 1000000))
          (list "log1p" qflog1p bflog1p (gen:val-in -3/4 1000000))
          ;; tgamma carries an explicit, looser tolerance (5th element): on older
          ;; libquadmath it drifts well past 64 ULP for moderate arguments.
          (list "tgamma" qftgamma bfgamma (gen:val-in 1/2 100) TOL-GAMMA)
          (list "lgamma" qflgamma bflog-gamma (gen:val-in 1/2 1000))))

  (for ([row (in-list unary-approx)])
    (define name (car row))
    (define qop (cadr row))
    (define bop (caddr row))
    (define g (cadddr row))
    (define tol (if (>= (length row) 5) (list-ref row 4) TOL))
    (test-case (format "qf~a ~~ bf-~a" name name)
      (check-property cfg (property ([x g]) (approx? (qop (car x)) (bop (cdr x)) tol)))))

  ;; binary transcendentals
  (test-case "qfpow ~ bfexpt (relative error <= 2^-106)"
    (check-property
     cfg
     (property ([base (gen:val #:emin -5 #:emax 5 #:sign 'nonneg)] [ex (gen:val-in -10 10)])
               (approx? (qfpow (car base) (car ex)) (bfexpt (cdr base) (cdr ex))))))
  (test-case "qfhypot ~ bfhypot (relative error <= 2^-106)"
    (check-property cfg
                    (property ([a (gen:val #:emin -60 #:emax 60)] [b (gen:val #:emin -60 #:emax 60)])
                              (approx? (qfhypot (car a) (car b)) (bfhypot (cdr a) (cdr b))))))
  (test-case "qfatan2 ~ bfatan2 (relative error <= 2^-106)"
    (check-property cfg
                    (property ([a (gen:val)] [b (gen:val)])
                              (approx? (qfatan2 (car a) (car b)) (bfatan2 (cdr a) (cdr b)))))))
