#lang racket/base

(require rackunit
         "quadf.rkt")

(let* ([d 1.0]
       [q (df2qf d)])
  (check-equal? (qf2df (addq q q)) 2.0 "Simple addition"))
