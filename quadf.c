// a wrapper for quad precision ops

#include <stdint.h>

typedef struct {
  uint64_t fh;
  uint64_t sh;
} _qf;

void addq(_qf* a, _qf* b, _qf* r) {
  __float128* qa = (__float128*)a;
  __float128* qb = (__float128*)b;
  __float128* qr = (__float128*)r;
  *qr = *qa + *qb;
}
