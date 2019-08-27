// a wrapper for quad precision ops

#include <stdint.h>
#include <string.h>


typedef struct {
  uint64_t fh;
  uint64_t sh;
} _qf;

// simple arithmetic
void addq(_qf* a, _qf* b, _qf* r) {
  __float128 qa;
  __float128 qb;
  __float128 qr;
  memcpy(&qa, a, sizeof(qa));
  memcpy(&qb, b, sizeof(qb));
  qr = qa + qb;
  memcpy(r, &qr, sizeof(qr));
}

void subq(_qf* a, _qf* b, _qf* r) {
  __float128 qa;
  __float128 qb;
  __float128 qr;
  memcpy(&qa, a, sizeof(qa));
  memcpy(&qb, b, sizeof(qb));
  qr = qa - qb;
  memcpy(r, &qr, sizeof(qr));
}

void mulq(_qf* a, _qf* b, _qf* r) {
  __float128 qa;
  __float128 qb;
  __float128 qr;
  memcpy(&qa, a, sizeof(qa));
  memcpy(&qb, b, sizeof(qb));
  qr = qa * qb;
  memcpy(r, &qr, sizeof(qr));
}

void div(_qf* a, _qf* b, _qf* r) {
  __float128 qa;
  __float128 qb;
  __float128 qr;
  memcpy(&qa, a, sizeof(qa));
  memcpy(&qb, b, sizeof(qb));
  qr = qa / qb;
  memcpy(r, &qr, sizeof(qr));
}

void df2qf(double d, _qf* r) {
  __float128 qv = (__float128)d;
  memcpy(r, &qv, sizeof(qv));
}

double qf2df(_qf* r) {
  __float128 qv;
  memcpy(&qv, r, sizeof(qv));
  return qv;
}
