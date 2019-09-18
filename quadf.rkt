#lang racket/base

(require ffi/unsafe
         ffi/unsafe/define
         (for-syntax racket/base
                     racket/syntax
                     syntax/parse))

(provide (rename-out [addQ qf+])
         (rename-out [subQ qf-])
         (rename-out [mulQ qf*])
         (rename-out [divQ qf/])
         (rename-out [absQ qfabs])
         (rename-out [sqrtQ qfsqrt])
         Quad-fh
         Quad-sh
         (rename-out [df2qf double-flonum->quad-flonum])
         (rename-out [qf2df quad-flonum->double-flonum])
         (rename-out [eq qf=])
         (rename-out [lt qf<])
         (rename-out [le qf<=])
         (rename-out [gt qf>])
         (rename-out [ge qf>=])
         Quad?)

(define-cstruct _Quad ([fh _uint64] [sh _uint64]))

(define-ffi-definer define-quad (ffi-lib "libquadf"))

(begin-for-syntax
  (define (build-args arity)
    (build-list
     (syntax->datum arity)
     (λ (x) #'_Quad-pointer)))
  (define (format-op-names op-names)
    (map
     (λ (op-name)
       (format-id op-name "~aQ" op-name))
     (syntax->list op-names))))

(define-syntax (define-nary-ops stx)
  (syntax-case stx ()
    [(_ arity op-name ...)
     (with-syntax ([(op-name-q ...)
                    (format-op-names #'(op-name ...))])
       #`(begin
           (define-quad op-name-q
             (_fun
              #,@(build-args #'arity)
              (r : (_ptr o _Quad))
              -> _void
              -> r)) ...))]))

(define-syntax (define-binary-relations stx)
  (syntax-case stx ()
    [(_ op-name ...)
     (with-syntax ([(op-name-q ...)
                    (format-op-names #'(op-name ...))])
       #`(begin
           (define-quad op-name-q
             (_fun
              #,@(build-args #'2)
              -> _ubyte)) ...
           (define (op-name x y)
             (> (op-name-q x y) 0)) ...))]))

;; TODO: make the macro like this
;; (define-nary-ops (add 2) (sub 2) (abs 1) ...)
;; just as an exercise
(define-nary-ops 2 add sub mul div)
(define-nary-ops 1 abs sqrt)
(define-binary-relations eq lt le gt ge)

(define-quad df2qf (_fun _double
                         (r : (_ptr o _Quad))
                         -> _void
                         -> r))

(define-quad qf2df (_fun _Quad-pointer 
                         -> _double))
