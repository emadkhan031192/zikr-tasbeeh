# Tasbeeh Zikr Counter

An offline digital tasbeeh / dhikr counter for Android (package
`com.afzal.zikrtasbeeh`). Open the app once to set everything up, then tap
**Start on-screen counter** — the counter floats on top of any other app and
keeps working there, even when Noor Tasbeeh is closed. The app itself is the
control panel and history; the overlay is the daily-use counter.

Fully offline. No ads. No login. No internet permission.

## Features

- **On-screen overlay** with three modes: draggable **bubble** (tap = +1,
  long-press = panel, snaps to the edge, remembers its position), compact
  **panel** (− / +1 / reset, dhikr name, progress), and **fullscreen**
  (tap anywhere to count).
- Foreground service with a persistent notification: **+1**, **Show/Hide**,
  **Stop** actions keep the overlay alive.
- 7 dhikr presets (SubhanAllah 33, Alhamdulillah 33, Allahu Akbar 34,
  Astaghfirullah 100, La ilaha illallah 100, Durood 100, Custom), each with
  its own saved count, target and rounds.
- Neon design: pure black `#04060C`, huge Nunito Black digits with a
  cyan→blue gradient and glow; 4 colour themes.
- Counting options: vibration strength, click sound, volume-button counting,
  step size, target behaviours (stop / new round / next dhikr), milestone
  vibrations, reset lock.
- Reminders: multiple daily/weekly reminders, prayer-based presets (offline
  adhan, Karachi method, Hanafi Asr, manual city/coordinates), "remind me if
  I have not counted today", snooze, Done action.
- History: last-30-days bar chart, all-time total, daily goal.
- Backup: export/import everything as a JSON file.
- English, Urdu and Pashto UI (Urdu/Pashto are RTL).
- Optional accessibility service so the volume buttons count while another
  app is open — it only reads volume key events, never the screen.

## Building on GitHub

Everything is built on GitHub Actions; no local build is needed.

1. Push to the `main` branch (or run the workflow manually from the
   **Actions** tab).
2. The workflow installs Flutter **3.47.7** (pinned), runs `flutter pub get`,
   `flutter analyze` and `flutter build apk --release --split-per-abi`.
3. Download the APKs from the run's **Artifacts** (`zikr-tasbeeh-apks`) —
   one APK per ABI (`arm64-v8a`, `armeabi-v7a`, `x86_64`).
4. Push a tag like `v1.0.0` to also create a **GitHub Release** with the
   APKs attached.

## Installing the APK

1. Download the APK matching your phone (almost always `arm64-v8a`).
2. Open it on the phone and allow "Install unknown apps" when asked.
3. Open **Tasbeeh Zikr Counter** and go through the **Setup** screen.

## Granting permissions (Setup screen)

Each row shows a green check or a red **Allow** button that opens the right
settings page:

| Permission | Needed for |
|---|---|
| Display over other apps | The on-screen counter itself |
| Notifications | The counter's persistent notification and reminders |
| Alarms & reminders | Exact-time reminders |
| Ignore battery optimization | Keeps the overlay and reminders alive in the background |
| Accessibility service (optional) | Volume buttons count while another app is open |

If a permission is denied the app keeps working — the affected feature is
explained on the row instead of crashing.

## Release signing (optional)

Without secrets the CI builds a **debug-signed** APK that installs and runs
fine. For a Play-Store-ready signature:

1. Create an upload keystore once:
   `keytool -genkeypair -v -keystore upload-keystore.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000`
2. In the GitHub repo go to **Settings → Secrets and variables → Actions**
   and add:
   - `KEYSTORE_BASE64` — base64 of the `.jks` file
     (`base64 -w0 upload-keystore.jks`)
   - `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`
3. The next build signs the release with your upload key automatically.

## Project structure

```
lib/
  main.dart, app.dart, background.dart   # entry points (+ headless boot callback)
  models/        # dhikr presets, settings, reminders
  l10n/          # English / Urdu / Pashto strings
  services/      # storage, counter, overlay/system bridges, reminders, feedback
  widgets/       # neon digit display
  screens/       # home, setup, settings, history, about, fullscreen counter
android/         # full native project (no `flutter create` needed)
  app/src/main/kotlin/com/afzal/zikrtasbeeh/
    MainActivity.kt            # method channels
    overlay/OverlayService.kt  # bubble / panel / fullscreen + foreground service
    CounterNative.kt           # counting logic shared with the overlay
    ZikrAccessibilityService.kt# volume-button counting
    BootReceiver.kt, HeadlessBoot.kt
    ConditionalReminderReceiver.kt  # "not counted today" alarm
```

## Technical notes

- The overlay is a **native Kotlin** `WindowManager` overlay driven by a
  foreground service (the spec's approved fallback), not a plugin: this is
  what makes edge-snapping drag, notification actions and tap-through
  reliable. The Flutter app and the overlay share one store
  (SharedPreferences, keys documented in `lib/services/storage.dart`), and
  every tap is saved immediately — even if the main app was killed.
- `minSdk` is **24** (Android 7.0) instead of 23 because
  `flutter_local_notifications` 21+ requires API 24.
- Scheduled reminders are re-armed on reboot through a headless Flutter
  callback (`background.dart`), since Android clears alarms on reboot.
- Prayer times are computed fully offline with the `adhan` package; no
  location permission is used.
