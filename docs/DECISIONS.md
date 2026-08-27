## ADR-001 — Do not use Android GeofencingClient

Status: Proposed

### Context

The assessment uses the phrase geo-fenced attendance and requires an exact
50-meter validation while AttendanceScreen is visible.

### Decision

Use foreground Fused Location Provider updates and calculate the distance
directly rather than relying on Android GeofencingClient.

### Why

Android's official Geofencing guidance recommends approximately 100–150 meter
minimum radii for reliable geofence behavior and geofence transitions may have
latency.

Foreground high-accuracy location updates better match the assessment's
real-time 50-meter validation requirement.

### Consequences

- No background-location permission required.
- Immediate screen feedback is possible.
- Location updates must be lifecycle-aware and stopped when no longer needed.