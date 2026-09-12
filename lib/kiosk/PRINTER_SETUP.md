# Kiosk receipt printer (Xprinter XP-58H)

The kiosk auto-prints a ticket on a Bluetooth thermal printer right after a
submission succeeds ([kiosk_printer.dart](kiosk_printer.dart)). This only works
in a **native Android build** — the XP-58H pairs as classic Bluetooth (SPP),
which the browser's Web Bluetooth API (BLE-only) cannot reach. Running the
kiosk as a Chrome/web build, printing is silently skipped.

## One-time setup, per kiosk tablet

1. Power on the XP-58H and put it in pairing mode (hold its power button per
   the printer's manual, usually until the LED blinks).
2. On the Android tablet: **Settings → Bluetooth → Pair new device** → select
   the printer (shows as something like `XP-58H` or `Printer001`). If asked
   for a PIN, try `0000` or `1234` — both are common defaults for this model.
3. That's it — the app only ever talks to an **already-bonded** device. It
   never scans for or pairs the printer itself.

## Granting the Bluetooth permission

There's no in-app permission prompt — a walk-up kiosk has no one standing by
to tap "Allow" the first time it tries to print. Grant it once, as part of
setting up the tablet, either:

- **Settings → Apps → iRequestDologon Kiosk → Permissions → Nearby devices →
  Allow**, or
- over ADB: `adb shell pm grant <applicationId> android.permission.BLUETOOTH_CONNECT`

If this step is skipped, printing just fails silently and the kiosk carries
on normally (see "If nothing prints" below) — nothing breaks, tickets just
don't come out.

## Building

```
flutter build apk -t lib/main_kiosk.dart \
  --dart-define=KIOSK_API_BASE=https://<your-backend>/api \
  --dart-define=KIOSK_KEY=<matches the backend's KIOSK_KEY> \
  --dart-define=KIOSK_PRINTER_NAME=XP-58H
```

`KIOSK_PRINTER_NAME` only matters if more than one Bluetooth device is ever
bonded to the tablet — it matches by a case-insensitive substring of the
bonded device's name. Leave it unset and the kiosk uses whichever single
device is bonded, which is the normal case for a dedicated kiosk tablet.

On first print, Android will prompt for the Bluetooth permission (Android 12+:
"Nearby devices"; older Android: "Location", which Bluetooth scanning has
historically required). Grant it once — the tablet remembers.

## Paper

58mm-class thermal roll stock. The XP-58H has no auto-cutter, so the ticket
ends with a couple of blank line feeds to leave enough bare paper to tear by
hand, rather than an actual paper-cut command. Content is kept to one short
fact per line by design — the ticket is meant to be small.

## If nothing prints

Printing is deliberately best-effort and never blocks the kiosk screen. If
the printer is off, out of paper, or out of Bluetooth range, the resident
still gets their on-screen OR number(s) and the kiosk carries on normally.
Check `adb logcat` for lines tagged `[kiosk-printer]` to see why a print
attempt was skipped or failed.
