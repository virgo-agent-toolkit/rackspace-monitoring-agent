
#include "virgo.h"

int main(int argc, char* argv[])
{
  virgo_t *v;

  virgo_create(&v);

  /* TODO: read path from config file */
  virgo_conf_lua_load_path(v, "./monitoring.lpack");

  virgo_run(v);

  virgo_destroy(v);

  return 0;
}


