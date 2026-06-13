#lang racket/base

;; Package entry point: `(require quad-fp)` re-exports the typed API
;; (the same bindings as `quad-fp/quadf-typed`).

(require "quadf-typed.rkt")
(provide (all-from-out "quadf-typed.rkt"))
