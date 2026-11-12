# Home Inventory (working name)

Home inventory and warranty tracker: rooms, items with photos and receipts, warranty end dates, 25 free items, insurance claim PDF with pictures and CSV.

Flutter app for Android and iOS. Everything stays on the device: no account,
no server. The free version covers the core; Pro is sold through the stores
(currently a local stand-in, see "Before the stores").

## Layout

| Path | What |
|------|------|
| apps/home_inventory | The app |
| packages/app_core | Shared core: settings, onboarding, paywall and entitlements, ratings prompt, CSV/PDF export, theme |
| packages/e2e_driver | Helpers for the end-to-end test and store screenshots |
| store/ | Store listing, data safety answers, privacy policy, screenshots, icon, feature graphic |
| tool/ | Store screenshot and art scripts |

`packages/` is a copy of the core shared with the other apps of the
portfolio. A fix there should be copied to the other app repos too.

## Set up

Needs Flutter 3.47 or newer (Dart 3.13).

```
flutter pub get
cd apps/home_inventory && dart run build_runner build   # database code generation
flutter run                                     # on a phone or emulator
```

## Tests

End-to-end is the main test: it drives the real app on a real database through
a realistic scenario (30 items with photos, $10,648.00 total, 59 checks) and writes checkable artifacts.

```
apps/home_inventory/tool/run_e2e.sh
# -> apps/home_inventory/test-artifacts/e2e/: result.json (every check, expected vs seen),
#    the exported CSV and PDF, the PDF as text, checksums.txt
```

It runs on the Linux desktop target (needs clang, cmake, ninja, GTK 3,
xvfb, poppler-utils), with a fixed clock and TZ=America/New_York, so the
CSV checksum is the same on every run. The isolated logic scenarios run with
`cd apps/home_inventory && TZ=America/New_York flutter test test/`; the failure modes
they cover are listed in `apps/home_inventory/docs/`.

Store screenshots: `tool/store_shots.sh` reruns the end-to-end test at
1080x1920 and saves pictures to store/home_inventory/screenshots/. It fails if any
check fails.

## Before the stores

See store/README.md. In short: final name and bundle id (currently
`com.placeholder.*`), signed builds (keep the upload key out of this repo),
RevenueCat in place of LocalEntitlementService, then Play internal testing.
