#lang racket/base

;;; A Racket FFI binding to GCC's libquadmath: IEEE 754 quadruple-precision
;;; (`__float128`) floating point, exposed to Racket as an opaque 128-bit value.
;;;
;;; `__float128` has no Racket FFI representation, so the C shim (quadf.c)
;;; shuttles each value as two uint64s; on this side a quad is an opaque
;;; `_Quad` struct that we only ever pass by pointer.

(require ffi/unsafe
         ffi/unsafe/define
         racket/runtime-path)

(provide qf+ qf- qf* qf/
         qfabs qfsqrt
         qf= qf< qf<= qf> qf>=
         double-flonum->quad-flonum
         quad-flonum->double-flonum
         Quad? Quad-fh Quad-sh)

;; Load libquadf from alongside this source file, so the binding works
;; regardless of the current working directory.
(define-runtime-path libquadf-path "libquadf")
(define-ffi-definer define-quad (ffi-lib libquadf-path))

;; A quad is 128 bits we never inspect from Racket, shuttled by pointer.
(define-cstruct _Quad ([fh _uint64] [sh _uint64]))

;; Value-returning ops take their operands as `_Quad` pointers and return a
;; freshly allocated `_Quad` through an out-parameter.
(define-syntax-rule (define-quad-unary name #:c-id c-id)
  (define-quad name
    (_fun _Quad-pointer (r : (_ptr o _Quad)) -> _void -> r)
    #:c-id c-id))

(define-syntax-rule (define-quad-binary name #:c-id c-id)
  (define-quad name
    (_fun _Quad-pointer _Quad-pointer (r : (_ptr o _Quad)) -> _void -> r)
    #:c-id c-id))

;; Relations come back from C as a byte; expose them as Racket booleans.
(define-syntax-rule (define-quad-relation name #:c-id c-id)
  (begin
    (define-quad c-pred
      (_fun _Quad-pointer _Quad-pointer -> _ubyte)
      #:c-id c-id)
    (define (name a b) (not (zero? (c-pred a b))))))

(define-quad-binary qf+ #:c-id addQ)
(define-quad-binary qf- #:c-id subQ)
(define-quad-binary qf* #:c-id mulQ)
(define-quad-binary qf/ #:c-id divQ)
(define-quad-unary qfabs  #:c-id absQ)
(define-quad-unary qfsqrt #:c-id sqrtQ)

(define-quad-relation qf=  #:c-id eqQ)
(define-quad-relation qf<  #:c-id ltQ)
(define-quad-relation qf<= #:c-id leQ)
(define-quad-relation qf>  #:c-id gtQ)
(define-quad-relation qf>= #:c-id geQ)

;; Conversions to and from Racket's native double flonums.
(define-quad double-flonum->quad-flonum
  (_fun _double (r : (_ptr o _Quad)) -> _void -> r)
  #:c-id df2qf)

(define-quad quad-flonum->double-flonum
  (_fun _Quad-pointer -> _double)
  #:c-id qf2df)
