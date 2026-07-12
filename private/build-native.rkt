#lang racket/base

;;; Pre-install hook (wired up via `pre-install-collection` in info.rkt).
;;;
;;; `raco pkg install` does not run the Makefile, so the FFI binding would have
;;; no shared library to load. We compile quadf.c into the platform-appropriate
;;; libquadf here, into the collection directory, where `define-runtime-path`
;;; in quadf.rkt looks for it. Requires GCC with libquadmath.

(require racket/list
         racket/system)

(provide pre-installer)

;; Split compiler settings without invoking a shell. This accepts the quoting
;; and escaping normally needed in CC/CFLAGS while keeping metacharacters such
;; as `;` and `$()` as ordinary compiler arguments.
(define (split-build-arguments variable value)
  (define value-length (string-length value))
  (define single-quote (integer->char 39))
  (define double-quote #\")
  ;; Native Windows tool paths conventionally contain backslashes; unlike a
  ;; POSIX shell, keep those literal while still honoring surrounding quotes.
  (define backslash-escapes? (not (eq? (system-type 'os) 'windows)))
  (define (emit-token token token-started? arguments)
    (if token-started?
        (cons (list->string (reverse token)) arguments)
        arguments))
  (let loop ([index 0]
             [quote-character #f]
             [escaped? #f]
             [token null]
             [token-started? #f]
             [arguments null])
    (cond
      [(= index value-length)
       (when escaped?
         (error 'quad-fp "~a ends with an incomplete escape" variable))
       (when quote-character
         (error 'quad-fp "~a contains an unmatched quote" variable))
       (reverse (emit-token token token-started? arguments))]
      [else
       (define character (string-ref value index))
       (cond
         [escaped?
          (loop (add1 index) quote-character #f (cons character token) #t arguments)]
         [quote-character
          (cond
            [(char=? character quote-character)
             (loop (add1 index) #f #f token #t arguments)]
            [(and backslash-escapes?
                  (char=? quote-character double-quote)
                  (char=? character #\\))
             (loop (add1 index) quote-character #t token #t arguments)]
            [else
             (loop (add1 index) quote-character #f (cons character token) #t arguments)])]
         [(char-whitespace? character)
          (loop (add1 index)
                #f
                #f
                null
                #f
                (emit-token token token-started? arguments))]
         [(or (char=? character single-quote) (char=? character double-quote))
          (loop (add1 index) character #f token #t arguments)]
         [(and backslash-escapes? (char=? character #\\))
          (loop (add1 index) #f #t token #t arguments)]
         [else
          (loop (add1 index) #f #f (cons character token) #t arguments)])])))

(define (environment-arguments variable [default null])
  (define value (getenv variable))
  (if value (split-build-arguments variable value) default))

;; Homebrew deliberately installs GCC under a versioned name such as gcc-15,
;; while macOS provides Apple Clang at /usr/bin/gcc. Search PATH and the two
;; standard Homebrew prefixes for a versioned GCC before falling back to gcc.
(define (compiler-search-directories)
  (define brew (find-executable-path "brew"))
  (define brew-bin
    (and brew
         (let-values ([(base _name _directory?) (split-path brew)])
           (and (path? base) base))))
  (remove-duplicates
   (filter path?
           (append (list brew-bin
                         (string->path "/opt/homebrew/bin")
                         (string->path "/usr/local/bin"))
                   (path-list-string->path-list (or (getenv "PATH") "") null)))
   equal?))

(define (versioned-gccs-in directory)
  (if (directory-exists? directory)
      (with-handlers ([exn:fail:filesystem? (lambda (_exception) null)])
        (for/fold ([candidates null]) ([name (in-list (directory-list directory))])
          (define match (regexp-match #px"^gcc-([0-9]+)$" (path->string name)))
          (define candidate (and match (build-path directory name)))
          (define executable (and candidate (find-executable-path candidate)))
          (if executable
              (cons (cons (string->number (cadr match)) executable) candidates)
              candidates)))
      null))

(define (find-versioned-gcc)
  (define candidates
    (append-map versioned-gccs-in (compiler-search-directories)))
  (and (pair? candidates)
       (cdar (sort candidates > #:key car))))

(define (select-compiler)
  (define configured (getenv "CC"))
  (cond
    [configured
     (define command (split-build-arguments "CC" configured))
     (unless (pair? command)
       (error 'quad-fp "CC is set but empty"))
     (define executable (find-executable-path (car command)))
     (unless executable
       (error 'quad-fp "compiler from CC was not found: ~a" (car command)))
     (values executable (cdr command))]
    [else
     (define executable
       (or (and (eq? (system-type 'os) 'macosx) (find-versioned-gcc))
           (find-executable-path "gcc")
           (find-executable-path "cc")))
     (unless executable
       (error 'quad-fp
              "cannot build libquadf: no compiler found (set CC to a GCC with libquadmath)"))
     (values executable null)]))

;; raco setup calls this as (pre-installer <collects-parent> <collection-dir>).
(define (pre-installer _collects-parent collection-dir)
  (define c-src (build-path collection-dir "quadf.c"))
  (define so-out
    (build-path collection-dir
                (bytes->string/utf-8
                 (bytes-append #"libquadf" (system-type 'so-suffix)))))
  (define-values (cc cc-prefix-arguments) (select-compiler))
  (define windows? (eq? (system-type 'os) 'windows))
  (define macos? (eq? (system-type 'os) 'macosx))
  (define arguments
    (append cc-prefix-arguments
            (environment-arguments "CPPFLAGS")
            (environment-arguments "CFLAGS" '("-O3"))
            (environment-arguments "PICFLAGS" (if windows? null '("-fPIC")))
            (environment-arguments "LDFLAGS")
            (environment-arguments "SHARED_LDFLAGS"
                                   (if macos? '("-dynamiclib") '("-shared")))
            (list "-o" (path->string so-out) (path->string c-src))
            (environment-arguments "LDLIBS")
            (environment-arguments "QUADMATH_LIBS" '("-lquadmath"))))
  (printf "quad-fp: compiling ~a -> ~a with ~a\n" c-src so-out cc)
  (unless (apply system* cc arguments)
    (error 'quad-fp
           "failed to compile ~a (set CC to GCC and ensure libquadmath is installed)"
           so-out)))
