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

  ;; Relative tolerances (1 ULP = 2^-112 for binary128). The bounds looser than
  ;; "exact" accommodate older libquadmath builds (e.g. the package server's):
  ;;   sqrt  — without soft-fp, sqrtq refines a (double)sqrt seed with Newton
  ;;           steps and no final correcting rounding, so it is faithfully
  ;;           (<=1 ULP), not correctly, rounded; recent builds round correctly
  ;;           (Innocente-Zimmermann measure binary128 sqrt at 0.5 ULP).
  ;;   fma   — older fmaq is a true (Dekker/Knuth, cancellation-safe) fma but
  ;;           lacks the round-to-odd step, so it can double-round by <=1 ULP.
  ;;   gamma — tgammaq varies most by version: glibc's binary128 tgamma peaks
  ;;           near 11 ULP, but the server's older libquadmath exceeds 64 ULP.
  ;;           4M ULP still pins ~27 correct digits — enough to catch a mis-bound
  ;;           function, bad marshalling, or a wrong scale, which is the point.
  (define TOL-RND (2^ -110)) ;     4 ULP — near-correctly-rounded (sqrt, fma)
  (define TOL (2^ -106)) ;        64 ULP — transcendentals
  (define TOL-GAMMA (2^ -90)) ; ~4M ULP — gamma (version-dependent; see above)
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
  (test-case "qfsqrt ~ bfsqrt (<= 4 ULP; bit-exact on recent libquadmath)"
    (check-property cfg
                    (property ([a (gen:val #:sign 'nonneg)])
                              (approx? (qfsqrt (car a)) (bfsqrt (cdr a)) TOL-RND))))
  (test-case "qfabs = bfabs"
    (check-property cfg (property ([a (gen:val)]) (exact? (qfabs (car a)) (bfabs (cdr a))))))
  (test-case "qffma ~ round(a*b+c) with a single rounding (<= 4 ULP)"
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
