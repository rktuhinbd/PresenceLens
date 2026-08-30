# Native Android Test Strategy

**What this document is for:** it defines the verification strategy for the Native Android PresenceLens application, tracking exactly what was tested, how it was executed, and explicitly acknowledging what was not separately executed.

## Verification Totals
Final known test total for the Native Android layer: **158** tests.

## 1. AUTOMATED

The automated suite focuses strictly on proving the mandated rules and ensuring architectural purity without inflating coverage numbers with brittle tests.

- **Pure domain tests:**
  - `AttendanceRule` is tested at 0 / 49.9 / 50.0 / 50.1 / 120 m boundaries using pure JUnit, proving `AND-08` exactly.
- **State/ViewModel tests:**
  - `AttendanceViewModel` state sequences are tested with fake location and office flows to verify the state machine (e.g., transition from `AcquiringFix` to `Tracking`), proving `AND-12` and `GEN-04`.
  - Permission, services-off, and no-fix states are thoroughly verified.
- **Persistence/repository tests:**
  - `OfficeLocationRepository` is tested against DataStore to ensure the office anchor is correctly saved and restored.
- **Architecture/purity checks:**
  - `DomainLayerPurityTest` asserts that the `domain` module contains zero Android dependencies, guaranteeing that business rules remain completely isolated from the framework.

## 2. EMULATOR / MANUAL

Behavior that genuinely requires hardware interaction or specific OS state manipulation was verified manually and recorded as evidence.

- **Emulator manual acceptance:**
  - Verified GPS movement spoofing to test real-time distance calculations and state transitions (in/out of 50m range).
  - Verified edge cases such as revoking permissions mid-session or toggling airplane mode.
- **Final runtime screenshot evidence:**
  - The final visual states (e.g., Setup, Ready, Out of Range) were captured directly from the emulator/device. These screenshots act as the primary visual proof of implementation fidelity against the design reference.

## 3. NOT SEPARATELY EXECUTED

- **Compose UI tests:** NOT SEPARATELY EXECUTED. Visual rendering and enabled/disabled button states were verified manually during the emulator acceptance phase rather than through automated Compose UI assertions.
- **Physical Native Android QA:** NOT SEPARATELY EXECUTED. A final screenshot captured from a device/emulator is runtime evidence, but it is not proof of a complete physical-device Native QA matrix. Hardware-specific sensor nuances were not exhaustively tested on physical devices.
