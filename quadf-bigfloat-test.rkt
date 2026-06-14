#lang racket/base

;; Property-based tests (rackcheck) that check the quad ops against
;; `math/bigfloat` at 113-bit precision — i.e. the binary128 significand width.
;;
;; The split matters: IEEE 754 requires `+ - * /`, `sqrt`, and `fma` to be
;; correctly rounded, and MPFR/bigfloat is correctly rounded too, so those must
;; match bigfloat *bit for bit*. libquadmath's transcendentals are not
;; guaranteed correctly rounded, so those are only checked to a tight ULP bound
;; (measured < 1 ULP; the bound here is a generous 64 ULP).
;;
;; Lives in a `test` submodule so rackcheck-lib and math-lib stay build-time
;; dependencies.

(module+ test
  (require rackcheck
           rackunit
           math/bigfloat
           "quadf-typed.rkt")

  (bf-precision 113) ; binary128 significand width
  (define cfg (make-config #:tests 10000 #:seed 1337))

  ;; --- bridge: a quad and a bigfloat denoting the same binary128 value -----
  ;; quad -> bigfloat is exact: 36 significant digits round-trips binary128.
  (define (q->bf q)
    (bf (quad-flonum->string q)))
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
             (cons (string->quad-flonum (bigfloat->string b)) b)))

  ;; Generator of values spread linearly across [lo, hi] (bounded domains).
  (define (gen:val-in lo hi)
    (gen:let ([bs (gen:bytes)])
             (define len (max 1 (bytes-length bs)))
             (define frac (bf/ (bf (bytes->nat bs)) (2^ (* 8 len)))) ; [0,1)
             (define b (bf+ (bf lo) (bf* (bf- (bf hi) (bf lo)) frac)))
             (cons (string->quad-flonum (bigfloat->string b)) b)))

  ;; --- comparison ----------------------------------------------------------
  (define (exact? q-result bf-result)
    (bf= (q->bf q-result) bf-result))

  (define TOL (2^ -106)) ; 64 ULP relative (1 ULP = 2^-112)
  (define (approx? q-result bf-result)
    (define got (q->bf q-result))
    (if (bfzero? bf-result)
        (bf<= (bfabs got) TOL)
        (bf<= (bfabs (bf/ (bf- got bf-result) bf-result)) TOL)))

  ;; --- exact: correctly-rounded ops match bigfloat bit for bit -------------
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
  (test-case "qfsqrt = bfsqrt"
    (check-property cfg
                    (property ([a (gen:val #:sign 'nonneg)])
                              (exact? (qfsqrt (car a)) (bfsqrt (cdr a))))))
  (test-case "qfabs = bfabs"
    (check-property cfg (property ([a (gen:val)]) (exact? (qfabs (car a)) (bfabs (cdr a))))))
  (test-case "qffma = round(a*b+c) with a single rounding"
    (check-property cfg
                    (property ([a (gen:val #:emin -40 #:emax 40)] [b (gen:val #:emin -40 #:emax 40)]
                                                                  [c (gen:val #:emin -40 #:emax 40)])
                              ;; correctly-rounded fused multiply-add: a*b+c exact (500 bits), then
                              ;; one rounding to 113 bits.
                              (define ref
                                (parameterize ([bf-precision 113])
                                  (bf+ (parameterize ([bf-precision 500])
                                         (bf+ (bf* (cdr a) (cdr b)) (cdr c)))
                                       (bf 0))))
                              (exact? (qffma (car a) (car b) (car c)) ref))))

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

  ;; --- approx: transcendentals within 64 ULP of correctly-rounded bigfloat -
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
          (list "tgamma" qftgamma bfgamma (gen:val-in 1/2 100))
          (list "lgamma" qflgamma bflog-gamma (gen:val-in 1/2 1000))))

  (for ([row (in-list unary-approx)])
    (define name (car row))
    (define qop (cadr row))
    (define bop (caddr row))
    (define g (cadddr row))
    (test-case (format "qf~a ~~ bf-~a (<= 64 ULP)" name name)
      (check-property cfg (property ([x g]) (approx? (qop (car x)) (bop (cdr x)))))))

  ;; binary transcendentals
  (test-case "qfpow ~ bfexpt (<= 64 ULP)"
    (check-property
     cfg
     (property ([base (gen:val #:emin -5 #:emax 5 #:sign 'nonneg)] [ex (gen:val-in -10 10)])
               (approx? (qfpow (car base) (car ex)) (bfexpt (cdr base) (cdr ex))))))
  (test-case "qfhypot ~ bfhypot (<= 64 ULP)"
    (check-property cfg
                    (property ([a (gen:val #:emin -60 #:emax 60)] [b (gen:val #:emin -60 #:emax 60)])
                              (approx? (qfhypot (car a) (car b)) (bfhypot (cdr a) (cdr b))))))
  (test-case "qfatan2 ~ bfatan2 (<= 64 ULP)"
    (check-property cfg
                    (property ([a (gen:val)] [b (gen:val)])
                              (approx? (qfatan2 (car a) (car b)) (bfatan2 (cdr a) (cdr b)))))))
