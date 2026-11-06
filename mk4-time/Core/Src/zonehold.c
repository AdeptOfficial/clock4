#include <string.h>
#include "zonehold.h"

static char candidate[32];
static uint32_t candidateSince, candidateLast;
static _Bool confirmed = 0; // a lookup has agreed with the zone in use since power-up

_Bool zoneHoldAccept(const char *loaded, const char *zone, uint32_t now) {

  // Nothing loaded yet (first power-up, or backup registers lost): take it
  if (!loaded[0]) {
    candidate[0] = 0;
    confirmed = 0;
    return 1;
  }

  // Lookup agrees with the zone in use: it is confirmed, drop any candidate
  if (strcmp(zone, loaded) == 0) {
    confirmed = 1;
    candidate[0] = 0;
    return 0;
  }

  // A different zone, either new or after a gap in lookups: start counting
  if (strcmp(zone, candidate) != 0 || now - candidateLast > ZONE_CONFIRM_MAX_GAP) {
    strncpy(candidate, zone, sizeof candidate - 1);
    candidate[sizeof candidate - 1] = 0;
    candidateSince = now;
    candidateLast = now;
    return 0;
  }

  candidateLast = now;
  if (now - candidateSince >= (confirmed ? ZONE_CONFIRM_SECONDS : ZONE_UNCONFIRMED_SECONDS)) {
    candidate[0] = 0;
    confirmed = 1; // every lookup agreed with it for the whole period
    return 1;
  }
  return 0;
}
