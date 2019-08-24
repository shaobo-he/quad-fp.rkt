#lang racket/base

(require ffi/unsafe
         ffi/unsafe/define)

(define-cstruct _Quad ([fb _uint64] [sb _uint64]))

(define-ffi-definer define-quad (ffi-lib "libquadf"))

(define-quad addq (_fun _Quad-pointer
                        _Quad-pointer
                        (r : (_ptr o _Quad))
                        -> _void
                        -> r))

(define-quad df2qf (_fun _double
                         (r : (_ptr o _Quad))
                         -> _void
                         -> r))

(define-quad qf2df (_fun _Quad-pointer 
                         -> _double))

(define q1 (df2qf 1.0))

(displayln (Quad-fb q1))
(displayln (Quad-sb q1))
