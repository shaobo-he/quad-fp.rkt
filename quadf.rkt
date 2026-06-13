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

;; arithmetic
(provide qf+
         qf-
         qf*
         qf/
         ;; unary math
         qfabs
         qfsqrt
         qfcbrt
         qfsin
         qfcos
         qftan
         qfasin
         qfacos
         qfatan
         qfsinh
         qfcosh
         qftanh
         qfasinh
         qfacosh
         qfatanh
         qfexp
         qfexp2
         qfexpm1
         qflog
         qflog2
         qflog10
         qflog1p
         qflogb
         qfceil
         qffloor
         qftrunc
         qfround
         qfrint
         qfnearbyint
         qferf
         qferfc
         qflgamma
         qftgamma
         qfj0
         qfj1
         qfy0
         qfy1
         ;; binary / ternary math
         qfpow
         qfatan2
         qfhypot
         qffmod
         qfremainder
         qfcopysign
         qffdim
         qfmax
         qfmin
         qfnextafter
         qffma
         ;; relations
         qf=
         qf<
         qf<=
         qf>
         qf>=
         ;; classification
         qfnan?
         qfinfinite?
         qffinite?
         qfsignbit?
         qfsignaling?
         ;; conversions
         double-flonum->quad-flonum
         quad-flonum->double-flonum
         string->quad-flonum
         quad-flonum->string
         ;; struct
         Quad?
         Quad-fh
         Quad-sh
         ;; constants
         quad-pi
         quad-pi/2
         quad-pi/4
         quad-1/pi
         quad-2/pi
         quad-2/sqrt-pi
         quad-e
         quad-log2e
         quad-log10e
         quad-ln2
         quad-ln10
         quad-sqrt2
         quad-1/sqrt2
         quad-max
         quad-min
         quad-epsilon
         quad-denorm-min
         quad-mant-dig
         quad-decimal-dig
         quad-min-exp
         quad-max-exp
         quad-min-10-exp
         quad-max-10-exp)

;; Load libquadf from alongside this source file, so the binding works
;; regardless of the current working directory.
(define-runtime-path libquadf-path "libquadf")
(define-ffi-definer define-quad (ffi-lib libquadf-path))

;; A quad is 128 bits we never inspect from Racket, shuttled by pointer.
(define-cstruct _Quad ([fh _uint64] [sh _uint64]))

;; Value-returning ops take their operands as `_Quad` pointers and return a
;; freshly allocated `_Quad` through an out-parameter.
(define-syntax-rule (define-quad-unary name #:c-id c-id)
  (define-quad name (_fun _Quad-pointer (r : (_ptr o _Quad)) -> _void -> r) #:c-id c-id))

(define-syntax-rule (define-quad-binary name #:c-id c-id)
  (define-quad name
               (_fun _Quad-pointer _Quad-pointer (r : (_ptr o _Quad)) -> _void -> r)
               #:c-id c-id))

(define-syntax-rule (define-quad-ternary name #:c-id c-id)
  (define-quad name
               (_fun _Quad-pointer _Quad-pointer _Quad-pointer (r : (_ptr o _Quad)) -> _void -> r)
               #:c-id c-id))

;; Predicates come back from C as a byte; expose them as Racket booleans.
(define-syntax-rule (define-quad-relation name #:c-id c-id)
  (begin
    (define-quad c-pred (_fun _Quad-pointer _Quad-pointer -> _ubyte) #:c-id c-id)
    (define (name a b)
      (not (zero? (c-pred a b))))))

(define-syntax-rule (define-quad-predicate name #:c-id c-id)
  (begin
    (define-quad c-pred (_fun _Quad-pointer -> _ubyte) #:c-id c-id)
    (define (name a)
      (not (zero? (c-pred a))))))

;; --- arithmetic -----------------------------------------------------------
(define-quad-binary qf+ #:c-id addQ)
(define-quad-binary qf- #:c-id subQ)
(define-quad-binary qf* #:c-id mulQ)
(define-quad-binary qf/ #:c-id divQ)

;; --- unary math -----------------------------------------------------------
(define-quad-unary qfabs #:c-id absQ)
(define-quad-unary qfsqrt #:c-id sqrtQ)
(define-quad-unary qfcbrt #:c-id cbrtQ)
(define-quad-unary qfsin #:c-id sinQ)
(define-quad-unary qfcos #:c-id cosQ)
(define-quad-unary qftan #:c-id tanQ)
(define-quad-unary qfasin #:c-id asinQ)
(define-quad-unary qfacos #:c-id acosQ)
(define-quad-unary qfatan #:c-id atanQ)
(define-quad-unary qfsinh #:c-id sinhQ)
(define-quad-unary qfcosh #:c-id coshQ)
(define-quad-unary qftanh #:c-id tanhQ)
(define-quad-unary qfasinh #:c-id asinhQ)
(define-quad-unary qfacosh #:c-id acoshQ)
(define-quad-unary qfatanh #:c-id atanhQ)
(define-quad-unary qfexp #:c-id expQ)
(define-quad-unary qfexp2 #:c-id exp2Q)
(define-quad-unary qfexpm1 #:c-id expm1Q)
(define-quad-unary qflog #:c-id logQ)
(define-quad-unary qflog2 #:c-id log2Q)
(define-quad-unary qflog10 #:c-id log10Q)
(define-quad-unary qflog1p #:c-id log1pQ)
(define-quad-unary qflogb #:c-id logbQ)
(define-quad-unary qfceil #:c-id ceilQ)
(define-quad-unary qffloor #:c-id floorQ)
(define-quad-unary qftrunc #:c-id truncQ)
(define-quad-unary qfround #:c-id roundQ)
(define-quad-unary qfrint #:c-id rintQ)
(define-quad-unary qfnearbyint #:c-id nearbyintQ)
(define-quad-unary qferf #:c-id erfQ)
(define-quad-unary qferfc #:c-id erfcQ)
(define-quad-unary qflgamma #:c-id lgammaQ)
(define-quad-unary qftgamma #:c-id tgammaQ)
(define-quad-unary qfj0 #:c-id j0Q)
(define-quad-unary qfj1 #:c-id j1Q)
(define-quad-unary qfy0 #:c-id y0Q)
(define-quad-unary qfy1 #:c-id y1Q)

;; --- binary / ternary math ------------------------------------------------
(define-quad-binary qfpow #:c-id powQ)
(define-quad-binary qfatan2 #:c-id atan2Q)
(define-quad-binary qfhypot #:c-id hypotQ)
(define-quad-binary qffmod #:c-id fmodQ)
(define-quad-binary qfremainder #:c-id remainderQ)
(define-quad-binary qfcopysign #:c-id copysignQ)
(define-quad-binary qffdim #:c-id fdimQ)
(define-quad-binary qfmax #:c-id fmaxQ)
(define-quad-binary qfmin #:c-id fminQ)
(define-quad-binary qfnextafter #:c-id nextafterQ)
(define-quad-ternary qffma #:c-id fmaQ)

;; --- relations ------------------------------------------------------------
(define-quad-relation qf= #:c-id eqQ)
(define-quad-relation qf< #:c-id ltQ)
(define-quad-relation qf<= #:c-id leQ)
(define-quad-relation qf> #:c-id gtQ)
(define-quad-relation qf>= #:c-id geQ)

;; --- classification -------------------------------------------------------
(define-quad-predicate qfnan? #:c-id isnanQ)
(define-quad-predicate qfinfinite? #:c-id isinfQ)
(define-quad-predicate qffinite? #:c-id finiteQ)
(define-quad-predicate qfsignbit? #:c-id signbitQ)
(define-quad-predicate qfsignaling? #:c-id issignalingQ)

;; --- conversions ----------------------------------------------------------
(define-quad double-flonum->quad-flonum
             (_fun _double (r : (_ptr o _Quad)) -> _void -> r)
             #:c-id df2qf)

(define-quad quad-flonum->double-flonum (_fun _Quad-pointer -> _double) #:c-id qf2df)

(define-quad string->quad-flonum (_fun _string (r : (_ptr o _Quad)) -> _void -> r) #:c-id str2qf)

(define-quad quad-flonum->string/raw (_fun _Quad-pointer _bytes _int _int -> _int) #:c-id qf2str)

;; Render a quad with `precision` significant digits (default 36 round-trips
;; binary128 exactly).
(define (quad-flonum->string q [precision 36])
  (define size 128)
  (define buf (make-bytes size))
  (define n (quad-flonum->string/raw q buf size precision))
  (bytes->string/utf-8 (subbytes buf 0 (max 0 (min n (sub1 size))))))

;; --- constants ------------------------------------------------------------
;; The libquadmath macro values, parsed to their correctly-rounded binary128.
(define quad-pi (string->quad-flonum "3.141592653589793238462643383279502884"))
(define quad-pi/2 (string->quad-flonum "1.570796326794896619231321691639751442"))
(define quad-pi/4 (string->quad-flonum "0.785398163397448309615660845819875721"))
(define quad-1/pi (string->quad-flonum "0.318309886183790671537767526745028724"))
(define quad-2/pi (string->quad-flonum "0.636619772367581343075535053490057448"))
(define quad-2/sqrt-pi (string->quad-flonum "1.128379167095512573896158903121545172"))
(define quad-e (string->quad-flonum "2.718281828459045235360287471352662498"))
(define quad-log2e (string->quad-flonum "1.442695040888963407359924681001892137"))
(define quad-log10e (string->quad-flonum "0.434294481903251827651128918916605082"))
(define quad-ln2 (string->quad-flonum "0.693147180559945309417232121458176568"))
(define quad-ln10 (string->quad-flonum "2.302585092994045684017991454684364208"))
(define quad-sqrt2 (string->quad-flonum "1.414213562373095048801688724209698079"))
(define quad-1/sqrt2 (string->quad-flonum "0.707106781186547524400844362104849039"))

(define quad-max (string->quad-flonum "1.18973149535723176508575932662800702e4932"))
(define quad-min (string->quad-flonum "3.36210314311209350626267781732175260e-4932"))
(define quad-epsilon (string->quad-flonum "1.92592994438723585305597794258492732e-34"))
(define quad-denorm-min (string->quad-flonum "6.475175119438025110924438958227646552e-4966"))

;; Integer characteristics (FLT128_*).
(define quad-mant-dig 113)
(define quad-decimal-dig 33)
(define quad-min-exp -16381)
(define quad-max-exp 16384)
(define quad-min-10-exp -4931)
(define quad-max-10-exp 4932)
