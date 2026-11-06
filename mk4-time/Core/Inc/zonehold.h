#ifndef ZONEHOLD_H
#define ZONEHOLD_H

#include <stdint.h>

// A weak GPS fix can be reported as valid while the position is far from the
// truth. A single lookup must not move the clock to another zone, so a new
// zone is only accepted once every lookup has returned it for a while.

// Once a lookup has agreed with the zone in use since power-up, that zone is
// confirmed and a different one must hold for this long
#define ZONE_CONFIRM_SECONDS 600

// Until then (the zone came from the backup registers or the config file),
// a different zone replaces it sooner
#define ZONE_UNCONFIRMED_SECONDS 60

// Lookups further apart than this (no fix in between) restart the count.
#define ZONE_CONFIRM_MAX_GAP 60

// loaded: the zone currently in use ("" if none). zone: the zone just looked up.
// Returns 1 when the caller should load `zone` now.
_Bool zoneHoldAccept(const char *loaded, const char *zone, uint32_t now);

#endif
