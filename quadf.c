// Wrappers around libquadmath quad-precision (__float128) operations.
//
// __float128 has no Racket FFI representation, so every quad crosses the
// boundary as an opaque 16-byte struct (_qf): we memcpy it into a real
// __float128, compute, and memcpy the result back out.

#if defined(__APPLE__)
#define _DARWIN_C_SOURCE 1
#elif !defined(_WIN32)
#define _XOPEN_SOURCE 700
#endif

#include <ctype.h>
#include <limits.h>
#include <locale.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <quadmath.h>

#ifdef __APPLE__
#include <xlocale.h>
#endif

typedef struct {
  uint64_t fh;
  uint64_t sh;
} _qf;

typedef unsigned char BOOL_RES;

// Keep the C and Racket views of an opaque quad in lockstep. In particular,
// none of the memcpy calls below may copy beyond Racket's two-uint64 cstruct.
_Static_assert(CHAR_BIT == 8, "quad-fp requires 8-bit bytes");
_Static_assert(sizeof(uint64_t) == 8, "quad-fp requires 64-bit uint64_t");
_Static_assert(sizeof(__float128) == 16, "quad-fp requires 128-bit __float128");
_Static_assert(sizeof(_qf) == 16, "_qf must contain exactly 128 bits");
_Static_assert(offsetof(_qf, fh) == 0, "_qf first half has the wrong offset");
_Static_assert(offsetof(_qf, sh) == 8, "_qf second half has the wrong offset");
_Static_assert(sizeof(BOOL_RES) == 1, "predicate results must occupy one byte");

// strtoflt128 and quadmath_snprintf honor LC_NUMERIC. Switch only the calling
// thread to the C locale so conversions are deterministic without racing a
// process-global setlocale call.
#ifdef _WIN32
typedef struct {
  char* previous_name;
  int previous_mode;
} numeric_locale_guard;

static int enter_c_numeric_locale(numeric_locale_guard* guard) {
  // The Microsoft CRT makes subsequent setlocale calls thread-local after this
  // switch. MinGW exposes the same CRT interface.
  guard->previous_mode = _configthreadlocale(_ENABLE_PER_THREAD_LOCALE);
  if (guard->previous_mode == -1) {
    return 0;
  }

  const char* previous_name = setlocale(LC_NUMERIC, NULL);
  if (previous_name == NULL) {
    _configthreadlocale(guard->previous_mode);
    return 0;
  }
  size_t name_size = strlen(previous_name) + 1;
  guard->previous_name = malloc(name_size);
  if (guard->previous_name == NULL) {
    _configthreadlocale(guard->previous_mode);
    return 0;
  }
  memcpy(guard->previous_name, previous_name, name_size);

  if (setlocale(LC_NUMERIC, "C") == NULL) {
    free(guard->previous_name);
    _configthreadlocale(guard->previous_mode);
    return 0;
  }
  return 1;
}

static int leave_c_numeric_locale(numeric_locale_guard* guard) {
  int ok = setlocale(LC_NUMERIC, guard->previous_name) != NULL;
  free(guard->previous_name);
  if (_configthreadlocale(guard->previous_mode) == -1) {
    ok = 0;
  }
  return ok;
}
#else
typedef struct {
  locale_t c_locale;
  locale_t previous_locale;
} numeric_locale_guard;

static int enter_c_numeric_locale(numeric_locale_guard* guard) {
  guard->c_locale = newlocale(LC_NUMERIC_MASK, "C", (locale_t)0);
  if (guard->c_locale == (locale_t)0) {
    return 0;
  }

  guard->previous_locale = uselocale(guard->c_locale);
  if (guard->previous_locale == (locale_t)0) {
    freelocale(guard->c_locale);
    guard->c_locale = (locale_t)0;
    return 0;
  }
  return 1;
}

static int leave_c_numeric_locale(numeric_locale_guard* guard) {
  if (uselocale(guard->previous_locale) == (locale_t)0) {
    // The C locale is still active, so it cannot safely be freed.
    return 0;
  }
  freelocale(guard->c_locale);
  return 1;
}
#endif

// --- wrapper generators ---------------------------------------------------
// In each `expr`, qa/qb/qc name the loaded __float128 operands.

#define UNARY(name, expr)                                       \
  void name(_qf* a, _qf* r) {                                   \
    __float128 qa; memcpy(&qa, a, sizeof(qa));                  \
    __float128 qr = (expr);                                     \
    memcpy(r, &qr, sizeof(qr));                                 \
  }

#define BINARY(name, expr)                                      \
  void name(_qf* a, _qf* b, _qf* r) {                           \
    __float128 qa; memcpy(&qa, a, sizeof(qa));                  \
    __float128 qb; memcpy(&qb, b, sizeof(qb));                  \
    __float128 qr = (expr);                                     \
    memcpy(r, &qr, sizeof(qr));                                 \
  }

// unary predicate: __float128 -> bool
#define UPRED(name, expr)                                       \
  BOOL_RES name(_qf* a) {                                       \
    __float128 qa; memcpy(&qa, a, sizeof(qa));                  \
    return (expr) != 0;                                         \
  }

// binary relation: (__float128, __float128) -> bool
#define BPRED(name, expr)                                       \
  BOOL_RES name(_qf* a, _qf* b) {                               \
    __float128 qa; memcpy(&qa, a, sizeof(qa));                  \
    __float128 qb; memcpy(&qb, b, sizeof(qb));                  \
    return (expr);                                              \
  }

// --- arithmetic (compiler operators) --------------------------------------
BINARY(addQ, qa + qb)
BINARY(subQ, qa - qb)
BINARY(mulQ, qa * qb)
BINARY(divQ, qa / qb)

// --- unary math (libquadmath) ---------------------------------------------
UNARY(absQ, fabsq(qa))
UNARY(sqrtQ, sqrtq(qa))
UNARY(cbrtQ, cbrtq(qa))
UNARY(sinQ, sinq(qa))
UNARY(cosQ, cosq(qa))
UNARY(tanQ, tanq(qa))
UNARY(asinQ, asinq(qa))
UNARY(acosQ, acosq(qa))
UNARY(atanQ, atanq(qa))
UNARY(sinhQ, sinhq(qa))
UNARY(coshQ, coshq(qa))
UNARY(tanhQ, tanhq(qa))
UNARY(asinhQ, asinhq(qa))
UNARY(acoshQ, acoshq(qa))
UNARY(atanhQ, atanhq(qa))
UNARY(expQ, expq(qa))
UNARY(expm1Q, expm1q(qa))
UNARY(logQ, logq(qa))
UNARY(log2Q, log2q(qa))
UNARY(log10Q, log10q(qa))
UNARY(log1pQ, log1pq(qa))
UNARY(ceilQ, ceilq(qa))
UNARY(floorQ, floorq(qa))
UNARY(truncQ, truncq(qa))
UNARY(roundQ, roundq(qa))
UNARY(rintQ, rintq(qa))
UNARY(nearbyintQ, nearbyintq(qa))
UNARY(erfQ, erfq(qa))
UNARY(erfcQ, erfcq(qa))
UNARY(lgammaQ, lgammaq(qa))
UNARY(tgammaQ, tgammaq(qa))
UNARY(j0Q, j0q(qa))
UNARY(j1Q, j1q(qa))
UNARY(y0Q, y0q(qa))
UNARY(y1Q, y1q(qa))

// exp2(x) = 2^x, via powq. (exp2q is absent from some libquadmath versions,
// so we avoid the symbol to keep libquadf loadable everywhere.)
void exp2Q(_qf* a, _qf* r) {
  __float128 qa; memcpy(&qa, a, sizeof(qa));
  __float128 two = 2;
  __float128 qr = powq(two, qa);
  memcpy(r, &qr, sizeof(qr));
}

// --- binary math (libquadmath) --------------------------------------------
BINARY(powQ, powq(qa, qb))
BINARY(atan2Q, atan2q(qa, qb))
BINARY(hypotQ, hypotq(qa, qb))
BINARY(fmodQ, fmodq(qa, qb))
BINARY(remainderQ, remainderq(qa, qb))
BINARY(copysignQ, copysignq(qa, qb))
BINARY(fdimQ, fdimq(qa, qb))
BINARY(fmaxQ, fmaxq(qa, qb))
BINARY(fminQ, fminq(qa, qb))
BINARY(nextafterQ, nextafterq(qa, qb))

// --- ternary: fused multiply-add ------------------------------------------
void fmaQ(_qf* a, _qf* b, _qf* c, _qf* r) {
  __float128 qa; memcpy(&qa, a, sizeof(qa));
  __float128 qb; memcpy(&qb, b, sizeof(qb));
  __float128 qc; memcpy(&qc, c, sizeof(qc));
  __float128 qr = fmaq(qa, qb, qc);
  memcpy(r, &qr, sizeof(qr));
}

// --- relations (compiler operators) ---------------------------------------
BPRED(eqQ, qa == qb)
BPRED(ltQ, qa < qb)
BPRED(leQ, qa <= qb)
BPRED(gtQ, qa > qb)
BPRED(geQ, qa >= qb)

// --- classification predicates --------------------------------------------
UPRED(isnanQ, isnanq(qa))
UPRED(isinfQ, isinfq(qa))
UPRED(finiteQ, finiteq(qa))
UPRED(signbitQ, signbitq(qa))

// --- conversions: double <-> quad -----------------------------------------
void df2qf(double d, _qf* r) {
  __float128 qv = (__float128)d;
  memcpy(r, &qv, sizeof(qv));
}

double qf2df(_qf* r) {
  __float128 qv;
  memcpy(&qv, r, sizeof(qv));
  return (double)qv;
}

// --- conversions: string <-> quad -----------------------------------------
enum {
  STR2QF_OK = 0,
  STR2QF_INVALID = 1,
  STR2QF_LOCALE_ERROR = 2
};

// Parse exactly one number, allowing only surrounding C-locale whitespace.
// Overflow and underflow are valid conversions (to infinity and zero), just as
// they are for strtoflt128 itself. The result is initialized only on success.
int str2qf(const char* s, _qf* r) {
  numeric_locale_guard guard;
  if (!enter_c_numeric_locale(&guard)) {
    return STR2QF_LOCALE_ERROR;
  }

  char* end;
  __float128 qv = strtoflt128(s, &end);
  int valid = end != s;
  while (valid && isspace((unsigned char)*end)) {
    ++end;
  }
  valid = valid && *end == '\0';

  if (!leave_c_numeric_locale(&guard)) {
    return STR2QF_LOCALE_ERROR;
  }
  if (!valid) {
    return STR2QF_INVALID;
  }

  memcpy(r, &qv, sizeof(qv));
  return STR2QF_OK;
}

// Formats into buf (size bytes) with `prec` significant digits; returns the
// number of characters that would have been written (snprintf semantics).
// Racket bounds precision to 12000; retain a defensive INT_MAX check here
// because printf's dynamic precision argument is necessarily an int.
int qf2str(_qf* a, char* buf, size_t size, size_t prec) {
  if (prec == 0 || prec > (size_t)INT_MAX) {
    return -1;
  }

  __float128 qa;
  memcpy(&qa, a, sizeof(qa));

  numeric_locale_guard guard;
  if (!enter_c_numeric_locale(&guard)) {
    return -1;
  }
  int result = quadmath_snprintf(buf, size, "%.*Qg", (int)prec, qa);
  if (!leave_c_numeric_locale(&guard)) {
    return -1;
  }
  return result;
}
