#lang info

(define collection "quad-fp")
(define version "0.1")

(define pkg-desc "Quadruple-precision (IEEE 754 binary128) floats for Racket via libquadmath")
(define pkg-authors '("Shaobo He"))
(define license 'MIT)

;; Runtime: typed-racket-lib backs quadf-typed.rkt.
(define deps '("base" "typed-racket-lib"))

;; Build/test only: tests, and docs.
(define build-deps '("rackunit-lib" "scribble-lib" "racket-doc" "typed-racket-doc"))

(define scribblings '(("scribblings/quad-fp.scrbl" ())))

;; The FFI binding needs libquadf, a C shim that `raco pkg install` will not
;; build on its own. Compile it from source at install time (needs gcc +
;; libquadmath). See private/build-native.rkt.
(define pre-install-collection "private/build-native.rkt")
