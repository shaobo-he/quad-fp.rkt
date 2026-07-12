#lang racket/base

;; Small, reproducible benchmark for the untyped fast path. Run through
;; make bench; override QUADF_BENCH_ITERATIONS to trade speed for stability.

(require "../quadf.rkt")

(define (environment-positive-integer name default)
  (define text (getenv name))
  (define value (and text (string->number text)))
  (cond
    [(not text) default]
    [(and (exact-integer? value) (positive? value)) value]
    [else (error 'quadf-bench "~a must be a positive integer; received ~e" name text)]))

(define iterations (environment-positive-integer "QUADF_BENCH_ITERATIONS" 100000))
(define one (double-flonum->quad-flonum 1.0))
(define two (double-flonum->quad-flonum 2.0))
(define five (double-flonum->quad-flonum 5.0))
(define sink #f)

(define (benchmark label thunk)
  (collect-garbage)
  (define start (current-inexact-monotonic-milliseconds))
  (for ([_ (in-range iterations)])
    (set! sink (thunk)))
  (define elapsed-ms (- (current-inexact-monotonic-milliseconds) start))
  (printf "~a\t~a ns/call\n" label (* 1000000.0 (/ elapsed-ms iterations))))

(module+ main
  (printf "Racket ~a, machine ~a, iterations ~a\n"
          (version)
          (system-type 'machine)
          iterations)
  (benchmark "qfabs" (lambda () (qfabs one)))
  (benchmark "qf+" (lambda () (qf+ one two)))
  (benchmark "qf*" (lambda () (qf* one two)))
  (benchmark "qf/" (lambda () (qf/ one two)))
  (benchmark "qfsqrt" (lambda () (qfsqrt two)))
  (benchmark "qfsin" (lambda () (qfsin one)))
  (benchmark "qffma" (lambda () (qffma one two five)))
  (benchmark "qfexp" (lambda () (qfexp one)))
  (benchmark "qferf" (lambda () (qferf one)))
  (benchmark "qfpow" (lambda () (qfpow two five)))
  (benchmark "qftgamma" (lambda () (qftgamma five)))

  ;; Keep the last result observably live.
  (void sink))
