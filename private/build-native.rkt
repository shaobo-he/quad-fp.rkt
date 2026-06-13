#lang racket/base

;;; Pre-install hook (wired up via `pre-install-collection` in info.rkt).
;;;
;;; `raco pkg install` does not run the Makefile, so the FFI binding would have
;;; no shared library to load. We compile quadf.c into the platform-appropriate
;;; libquadf here, into the collection directory, where `define-runtime-path`
;;; in quadf.rkt looks for it. Requires gcc (or cc) and libquadmath.

(require racket/system)

(provide pre-installer)

;; raco setup calls this as (pre-installer <collects-parent> <collection-dir>).
(define (pre-installer _collects-parent collection-dir)
  (define c-src (build-path collection-dir "quadf.c"))
  (define so-out
    (build-path collection-dir
                (bytes->string/utf-8 (bytes-append #"libquadf" (system-type 'so-suffix)))))
  (define cc (or (find-executable-path "gcc") (find-executable-path "cc")))
  (unless cc
    (error 'quad-fp "cannot build ~a: no gcc/cc found on PATH" so-out))
  (printf "quad-fp: compiling ~a -> ~a\n" c-src so-out)
  (define ok?
    (apply system*
           cc
           "-shared"
           "-fPIC"
           "-O3"
           "-o"
           (path->string so-out)
           (path->string c-src)
           '("-lquadmath")))
  (unless ok?
    (error 'quad-fp "failed to compile ~a (need gcc + libquadmath installed)" so-out)))
