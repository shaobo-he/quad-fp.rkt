#lang racket/base

(require ffi/unsafe
         ffi/unsafe/define
         (for-syntax racket/base
                     syntax/parse))

(provide addq
         subq
         mulq
         divq
         absq
         sqrtq
         Quad-fh
         Quad-sh
         df2qf
         qf2df)

(define-cstruct _Quad ([fh _uint64] [sh _uint64]))

(define-ffi-definer define-quad (ffi-lib "libquadf"))

(define-syntax (define-nary-ops stx)
  (syntax-case stx ()
    [(_ arity op-name ...)
     (with-syntax ([(args ...)
                    (datum->syntax
                     stx
                     (build-list
                      (syntax->datum #'arity)
                      (λ (x) '_Quad-pointer)))])
       #'(begin (define-quad op-name
                  (_fun args ...
                        (r : (_ptr o _Quad))
                        -> _void
                        -> r)) ...))
     ]))

(define-nary-ops 2 addq subq mulq divq)
(define-nary-ops 1 absq sqrtq)

(define-quad df2qf (_fun _double
                         (r : (_ptr o _Quad))
                         -> _void
                         -> r))

(define-quad qf2df (_fun _Quad-pointer 
                         -> _double))
