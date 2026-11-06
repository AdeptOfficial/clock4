#ifndef ZONEHOLD_H
#define ZONEHOLD_H

#include <stdint.h>

// A weak GPS fix can be reported as valid while the position is far from the
// truth. A single lookup must not move the clock to another zone, so a new
// zone is only accepted once every lookup has returned it for this long.
#define ZONE_CONFIRM_SECONDS 600

// Lookups further apart than this (no fix in between) restart the count.
#define ZONE_CONFIRM_MAX_GAP 60

// loaded: the zone currently in use ("" if none). zone: the zone just looked up.
// Returns 1 when the caller should load `zone` now.
_Bool zoneHoldAccept(const char *loaded, const char *zone, uint32_t now);

#endif
