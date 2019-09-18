#lang racket/base

(require rackunit
         "quadf-typed.rkt")

(let* ([d 1.0]
       [q (double-flonum->quad-flonum d)]
       [qq (qf+ q q)])
  (check-equal? (quad-flonum->double-flonum qq) 2.0 "Simple addition")
  (check-true (qf= q q) "Identity true"))
