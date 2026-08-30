# PresenceLens Attendance Location Engine

**What this document is for:** it defines the specific location tracking mechanisms, boundaries, and failure handling built to satisfy the attendance requirements.

## Engine Overview

The application relies on a foreground `FusedLocationProviderClient` for location resolution.

### 1. The 50 m eligibility boundary
The core business logic is a pure **50 m attendance proximity rule** evaluation. The assessment describes a geo-fenced attendance system, but the implementation deliberately uses `FusedLocationProviderClient` coupled with direct distance evaluation (via `AttendanceRule`). This guarantees immediate 50 m eligibility calculation and enables a live distance presentation rather than relying on delayed OS-level geofence transition callbacks.

### 2. Location Capture & Updates
- **One-shot office capture:** When setting the office location, the app issues a discrete, high-accuracy (`GRANULARITY_FINE`), un-cached (`maxUpdateAge = 0`) location request. This waits up to 28 seconds to establish a firm anchor.
- **Continuous foreground position updates:** When tracking attendance, the client operates in a streaming `callbackFlow`.
- **Lifecycle subscription:** Updates are strictly tied to the UI lifecycle. Collection is active only while the app is in the foreground/resumed state. It stops completely when backgrounded.

### 3. Permissions & Capabilities
- **Permission model:** Handles the full spectrum of user states: Not requested, Granted, Denied once, and Permanently denied (which surfaces a deep link to Settings).
- **Precise vs Coarse behavior:** A coarse-only grant is actively detected and treated as insufficient. A coarse fix mathematically cannot resolve a 50 m boundary honestly (AMB-14).
- **Service-disabled state:** The `LocationServiceMonitor` detects if the user disables global OS location services and surfaces a blocking UI state (GEN-04).

### 4. Quality, Freshness & Retry
- **Accuracy/quality classification:** Fixes are classified based on their error radius. Unusable fixes are discarded; degraded fixes display a warning banner but still evaluate against the 50 m eligibility boundary.
- **Freshness bound:** A location fix older than 10 seconds (monotonic clock) is considered stale and prompts a `RefreshingFix` state.
- **Provider retry/backoff:** If the provider drops, the stream automatically attempts reconnection with a capped exponential backoff (1s → 2s → 5s) for the duration of the screen subscription.
- **Fail-closed decision behavior:** Without a current, valid, precise location fix, the mark attendance action remains closed.

## What this layer deliberately does not do

To keep the architecture minimal, honest, and strictly mapped to the assessment boundaries:
- **No GeofencingClient**: Background geofence entry/exit events do not support live distance rendering and introduce significant latency.
- **No background-location permission**: Not requested and not needed. Tracking operates entirely in the foreground.
- **No mock-location spoof detection**: Explicitly omitted to simplify the scope.
- **No invented GPS precision**: If the device hardware reports a wide error radius, the UI warns the user rather than mathematically assuming the center coordinate is flawless.

## ADR Provenance
- Canonical architecture decisions governing this layer can be found in the root [DECISIONS.md](../DECISIONS.md) ledger.
- For detailed reasoning on preferring FusedLocationProvider over GeofencingClient, see [ADR-001](../DECISIONS.md#adr-001).
- For reasoning on distance vs accuracy evaluation, see [ADR-015](../DECISIONS.md#adr-015).
