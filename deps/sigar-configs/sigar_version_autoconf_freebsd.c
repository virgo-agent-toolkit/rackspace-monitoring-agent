#include "sigar.h"

static sigar_version_t sigar_version = {
    __DATE__,
    "edf041dc7a84ba46a3f5a8b808370a884ee3f52b",
    "cksigar",
    "release",
    "freebsd",
    "FREEBSD",
    "SIGAR-1.7.0, "
    "SCM revision edf041dc7a84ba46a3f5a8b808370a884ee3f52b, "
    "built "__DATE__" as FREEBSD",
    1,
    7,
    0,
    0
};

SIGAR_DECLARE(sigar_version_t *) sigar_version_get(void)
{
    return &sigar_version;
}
