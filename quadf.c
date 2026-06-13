// a wrapper for quad precision ops

#include <stdint.h>
#include <string.h>
#include <quadmath.h>


typedef struct {
  uint64_t fh;
  uint64_t sh;
} _qf;

// simple arithmetic
void addQ(_qf* a, _qf* b, _qf* r) {
  __float128 qa;
  __float128 qb;
  __float128 qr;
  memcpy(&qa, a, sizeof(qa));
  memcpy(&qb, b, sizeof(qb));
  qr = qa + qb;
  memcpy(r, &qr, sizeof(qr));
}

void subQ(_qf* a, _qf* b, _qf* r) {
  __float128 qa;
  __float128 qb;
  __float128 qr;
  memcpy(&qa, a, sizeof(qa));
  memcpy(&qb, b, sizeof(qb));
  qr = qa - qb;
  memcpy(r, &qr, sizeof(qr));
}

void mulQ(_qf* a, _qf* b, _qf* r) {
  __float128 qa;
  __float128 qb;
  __float128 qr;
  memcpy(&qa, a, sizeof(qa));
  memcpy(&qb, b, sizeof(qb));
  qr = qa * qb;
  memcpy(r, &qr, sizeof(qr));
}

void divQ(_qf* a, _qf* b, _qf* r) {
  __float128 qa;
  __float128 qb;
  __float128 qr;
  memcpy(&qa, a, sizeof(qa));
  memcpy(&qb, b, sizeof(qb));
  qr = qa / qb;
  memcpy(r, &qr, sizeof(qr));
}

void absQ(_qf* a, _qf* r) {
  __float128 qa;
  __float128 qr;
  memcpy(&qa, a, sizeof(qa));
  qr = fabsq(qa);
  memcpy(r, &qr, sizeof(qr));
}

void sqrtQ(_qf* a, _qf* r) {
  __float128 qa;
  __float128 qr;
  memcpy(&qa, a, sizeof(qa));
  qr = sqrtq(qa);
  memcpy(r, &qr, sizeof(qr));
}

// binary relations
typedef unsigned char BOOL_RES;
BOOL_RES eqQ(_qf* a, _qf* b) {
  __float128 qa;
  __float128 qb;
  memcpy(&qa, a, sizeof(qa));
  memcpy(&qb, b, sizeof(qb));
  return qa == qb;
}

BOOL_RES ltQ(_qf* a, _qf* b) {
  __float128 qa;
  __float128 qb;
  memcpy(&qa, a, sizeof(qa));
  memcpy(&qb, b, sizeof(qb));
  return qa < qb;
}

BOOL_RES leQ(_qf* a, _qf* b) {
  __float128 qa;
  __float128 qb;
  memcpy(&qa, a, sizeof(qa));
  memcpy(&qb, b, sizeof(qb));
  return qa <= qb;
}

BOOL_RES gtQ(_qf* a, _qf* b) {
  __float128 qa;
  __float128 qb;
  memcpy(&qa, a, sizeof(qa));
  memcpy(&qb, b, sizeof(qb));
  return qa > qb;
}

BOOL_RES geQ(_qf* a, _qf* b) {
  __float128 qa;
  __float128 qb;
  memcpy(&qa, a, sizeof(qa));
  memcpy(&qb, b, sizeof(qb));
  return qa >= qb;
}

// conversions
void df2qf(double d, _qf* r) {
  __float128 qv = (__float128)d;
  memcpy(r, &qv, sizeof(qv));
}

double qf2df(_qf* r) {
  __float128 qv;
  memcpy(&qv, r, sizeof(qv));
  return qv;
}
