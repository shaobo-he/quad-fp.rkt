#lang racket/base

(require ffi/unsafe
         ffi/unsafe/define
         (for-syntax racket/base
                     syntax/parse)
         syntax/parse/define)

(define-cstruct _Quad ([fh _uint64] [sh _uint64]))

(define-ffi-definer define-quad (ffi-lib "libquadf"))

(define-simple-macro (define-binary-op op-name:id)
                     (define-quad op-name
                                  (_fun _Quad-pointer
                                        _Quad-pointer
                                        (r : (_ptr o _Quad))
                                        -> _void
                                        -> r)))

(define-syntax (define-binary-ops stx)
  (syntax-case stx ()
               [(_ op-name ...)
                #'(begin (define-binary-op op-name)...)]))

(define-binary-ops addq subq mulq divq)

(define-quad df2qf (_fun _double
                         (r : (_ptr o _Quad))
                         -> _void
                         -> r))

(define-quad qf2df (_fun _Quad-pointer 
                         -> _double))

(define q1 (df2qf 1.0))
(define q2 (df2qf 2.0))

(displayln (Quad-fh q1))
(displayln (Quad-sh q1))

(displayln (Quad-fh q2))
(displayln (Quad-sh q2))

(define q3 (mulq q1 q2))
(displayln (Quad-fh q3))
(displayln (Quad-sh q3))
