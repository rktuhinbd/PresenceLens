# Project State



**Current Assessment Status**: COMPLETE and FROZEN.



Both applications are complete, verified, and submitted in this repository for the Intelligent Machines technical assessment.



## 1. Assessment Status

- **Native Android (Task 1):** Complete.

- **Flutter (Task 2):** Complete.

- **Release Status:** A `v1.0.0` release tag has been created. The repository contains the published `PresenceLens-Attendance-v1.0.0.apk` (Native) and `PresenceLens-Capture-v1.0.0.apk` (Flutter) along with their respective SHA-256 checksums in the release notes:

- **Native APK:** PresenceLens-Attendance-v1.0.0.apk
  - SHA256: 48a6969e2dccf78a89b721b8ffd389060d68ef49a300f709f6a681d84f1dd142
- **Flutter APK:** PresenceLens-Capture-v1.0.0.apk
  - SHA256: 8677ba493843def56eb7cc46dc8319d488962df1571d01578517565ae4af2b90




## 2. Verification Totals

- **Native Android Tests:** 158 tests passing

- **Flutter Tests:** 521 tests passing

- **Combined Total:** 679 automated tests

- **Static Analysis:** Android Lint reports 0 errors. `flutter analyze` reports 0 issues.



## 3. QA Boundaries

Physical device QA was completed on a **HONOR DNP-NX9 (Android 16)**.



Important evidence boundaries:

- **No Physical iOS QA:** The Flutter app was configured for iOS but physical validation was performed exclusively on an Android device (as the delivered APK platform for Flutter submission evidence).

- **No broad device-generalization:** Performance and validation are claimed only for the tested configurations.

- **Samsung S25 evidence:** A Samsung Galaxy S25 was explicitly used to verify the physical multi-touch pinch-to-zoom interaction in the Flutter app.



## 4. Known Limitations

- **Honor/MagicOS WorkManager Constraint**: The Flutter app's background sync relies on Android's `WorkManager`. On Honor MagicOS devices, an OEM-specific constraint (`HN_USER_EXPERIENCE`) may silently withhold background execution from a freshly-installed app until the device's Settings → App launch panel is switched from "automatic" to "manual" for that app. This is an OS-level restriction with no code-level workaround.

- **Android physical lens identity:** Android OS Camera API limitations occasionally obscure the mapping between logical and physical lenses on some multi-lens devices. The Flutter camera engine degrades gracefully.
