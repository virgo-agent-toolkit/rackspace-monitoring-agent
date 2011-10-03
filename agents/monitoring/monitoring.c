
#include "virgo.h"

int main(int argc, char* argv[])
{
  virgo_t *v;

  virgo_create(&v);

  virgo_run(v);

  virgo_destroy(v);

  return 0;
}


