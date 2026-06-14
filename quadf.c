// Wrappers around libquadmath quad-precision (__float128) operations.
//
// __float128 has no Racket FFI representation, so every quad crosses the
// boundary as an opaque 16-byte struct (_qf): we memcpy it into a real
// __float128, compute, and memcpy the result back out.

#include <stdint.h>
#include <string.h>
#include <quadmath.h>

typedef struct {
  uint64_t fh;
  uint64_t sh;
} _qf;

typedef unsigned char BOOL_RES;

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
void str2qf(const char* s, _qf* r) {
  __float128 qv = strtoflt128(s, NULL);
  memcpy(r, &qv, sizeof(qv));
}

// Formats into buf (size bytes) with `prec` significant digits; returns the
// number of characters that would have been written (snprintf semantics).
int qf2str(_qf* a, char* buf, int size, int prec) {
  __float128 qa;
  memcpy(&qa, a, sizeof(qa));
  return quadmath_snprintf(buf, (size_t)size, "%.*Qg", prec, qa);
}
