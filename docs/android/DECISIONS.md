# PresenceLens Attendance — Decision Index

| Decision | Canonical ADR | Status | Why it matters to Task 1 |
| --- | --- | --- | --- |
| Provider vs Geofence | [ADR-001](../DECISIONS.md#adr-001) | Accepted | FusedLocationProviderClient foreground tracking enables live distance rendering instead of GeofencingClient limits. |
| Datastore for Config | [ADR-002](../DECISIONS.md#adr-002) | Accepted | Justifies why the office anchor is saved via DataStore without needing Room. |
| Compose Map Region | [ADR-003](../DECISIONS.md#adr-003) | Accepted | The location surface is custom Compose canvas, not Google Maps SDK, avoiding keys and dependencies. |
| Single Android Module | [ADR-004](../DECISIONS.md#adr-004) | Accepted | Explains the deliberate `:app`-only constraint to respect reviewer time. |
| Unified Attendance State | [ADR-006](../DECISIONS.md#adr-006) | Accepted | Combines permissions, services, and location into a single `StateFlow`. |
| Premium M3 Execution | [ADR-012](../DECISIONS.md#adr-012) | Accepted | The UX spec baseline for fidelity without adopting unstable libraries. |
| Max Age & Accuracy Bound | [ADR-014](../DECISIONS.md#adr-014) / [ADR-015](../DECISIONS.md#adr-015) | Accepted | 10s freshness and accurate fixes required for 50m boundaries. |
| Transient Confirmation | [ADR-016](../DECISIONS.md#adr-016) | Accepted | Explains why there is no local database history of attendance marks. |
| Domain Orchestration | [ADR-017](../DECISIONS.md#adr-017) | Accepted | `SetOfficeLocationUseCase` and `LocationReading` logic moved from ViewModel to domain layer. |
