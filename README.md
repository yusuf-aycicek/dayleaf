# dailywall

[![CI](https://github.com/yusuf-aycicek/dailywall/actions/workflows/ci.yml/badge.svg)](https://github.com/yusuf-aycicek/dailywall/actions/workflows/ci.yml)

*[Türkçe](README.tr.md)*

dailywall is an Android app that gives you a new wallpaper every day, made from your
interests: an English word for your level, a software tip, a motivational line or a
piece of general knowledge. Each wallpaper is drawn on the phone itself. The app has
no internet permission, no account, no ads and no analytics.

- **Daily, offline:** a background job sets the day's wallpaper on the lock screen,
  the home screen or both. If today's wallpaper is already set, the job exits at once.
- **Learns with you:** mark an English word "I know it" and it stops coming back. Mark
  it "Show again" and it comes back after 2, 5 and 10 days.
- **No repeats:** each category goes through all its items before any of them repeats.
  Categories take turns day by day.
- **Readable:** text stays clear of the lock-screen clock and the home-screen
  shortcuts. It shrinks to fit and always meets a WCAG contrast ratio of 4.5:1.
- **Three styles:** minimal, card and bold type. Backgrounds are generated from the
  date and the category.
- **Turkish and English**, Material 3, light and dark theme, large system fonts.

## Screenshots

Screenshots go in [`docs/screenshots/`](docs/screenshots/). To take them, see
[docs/guides.tr.md](docs/guides.tr.md#5-readme-ekran-görüntüleri).

| Onboarding | Today | Lock screen | Home screen |
|---|---|---|---|
| ![](docs/screenshots/onboarding.png) | ![](docs/screenshots/today.png) | ![](docs/screenshots/lock.png) | ![](docs/screenshots/home.png) |

## Architecture

The code has five layers, and each layer depends only on the layers below it.
`lib/app` connects them.

```mermaid
flowchart TD
    UI["ui<br/>screens, widgets"] --> APP["app<br/>Riverpod providers,<br/>DailyWallpaperService"]
    APP --> DOMAIN["domain<br/>daily selection, spaced repetition,<br/>settings, progress"]
    APP --> RENDER["rendering<br/>dart:ui canvas, templates,<br/>text fit, contrast"]
    APP --> PLATFORM["platform<br/>WallpaperPort, BackgroundTasks"]
    APP --> DATA["data<br/>content JSON, schema, AppStore"]
    DOMAIN --> DATA
    PLATFORM --> BRIDGE["packages/wallpaper_bridge<br/>Kotlin MethodChannel"]
    BRIDGE --> WM["Android WallpaperManager<br/>FLAG_LOCK / FLAG_SYSTEM"]
    PLATFORM --> WORK["workmanager<br/>periodic job"]
    CORE["core<br/>Clock, SeededRandom, AppConfig"]
```

| Layer | Folder | What it does |
|---|---|---|
| core | `lib/core` | An injectable `Clock`, a seeded random generator, and app constants such as names and links |
| data | `lib/data` | Content models, JSON schema checks, the loader, and local storage (`shared_preferences`) |
| domain | `lib/domain` | Picks the day's item deterministically, handles spaced repetition, and holds the settings and progress models |
| rendering | `lib/rendering` | Draws the wallpaper with `PictureRecorder`/`Canvas` at the screen's physical resolution. It works in the background isolate too |
| platform | `lib/platform`, `packages/wallpaper_bridge` | Sets the wallpaper and schedules the daily job. This is the only Android-specific code |
| app | `lib/app` | `DailyWallpaperService` (one entry point for the app and the background job) and the providers |
| ui | `lib/ui` | Screens: onboarding, today, history, favorites, settings, about |

Some design choices:

- **The wallpaper channel is a local plugin**, not code in `MainActivity`. WorkManager
  starts its own Flutter engine for the background job. Plugins are registered on that
  engine too, while code in `MainActivity` would not be.
- **The same service runs on open and in the background.** `ensureToday()` is
  idempotent. When the app opens it applies the wallpaper if the background job has
  not run yet, and both paths share one "already applied" key.
- **Selection is deterministic.** The order inside a category comes from a seed built
  from (category, cycle). The same day always gives the same item, and there are no
  repeats until the category is used up.

## Tech stack

Flutter (stable), Dart, Riverpod, shared_preferences, workmanager, share_plus,
flutter_localizations with ARB files, Kotlin for the wallpaper bridge. Fonts
(Manrope, Lora, JetBrains Mono, Anton; SIL Open Font License) are bundled in
`assets/fonts`. minSdk 24.

## Setup and run

Requirements: Flutter stable, the Android SDK, and an emulator or a phone.

```bash
flutter pub get
flutter run
```

On Windows, keep the project, `PUB_CACHE` and `GRADLE_USER_HOME` on paths that are
ASCII only with no spaces (for example `C:\dev\...`). If your user folder has non-ASCII
characters, also set `TEMP`/`TMP` to such a folder before building. Otherwise Gradle
and the JDK fail with "Unable to establish loopback connection".

Change the package name in **one place**: `android/gradle.properties`
(`dailywall.applicationId`, `dailywall.appLabel`).

### Tests

```bash
flutter analyze
dart run tools/validate_content.dart   # content report, exits 1 on errors
flutter test --exclude-tags golden     # what CI runs
```

CI also runs the size, safe-area and contrast tests (`test/rendering/rendering_test.dart`).

**Golden tests** (`test/rendering/golden_test.dart`, tagged `golden`) compare
wallpapers against PNG files in `test/rendering/goldens/`. Font rasterization differs
between operating systems, so CI does not run them. Run them locally:

```bash
flutter test --tags golden                    # compare
flutter test --tags golden --update-goldens   # regenerate after an intended change
```

After updating, look at the changed PNGs in `test/rendering/goldens/` before you
commit them.

### Testing the daily change without waiting

In a debug build, **Settings → Developer** can run the background job now, pretend it
is tomorrow, and show the background log. To trigger the real WorkManager job from a
terminal, see [docs/guides.tr.md](docs/guides.tr.md#3-arka-plan-görevini-beklemeden-test-etmek).

## Adding content

Content lives in `assets/content/<category>.json`, one file per category:

```json
{
  "category": "software_tips",
  "kind": "text",
  "items": [
    { "id": "sw_0031",
      "text":   { "en": "Short tip.",      "tr": "Kısa ipucu." },
      "detail": { "en": "One more line.",  "tr": "Bir satır daha." } }
  ]
}
```

English words use `"kind": "word"` with `level` (A1–C1), `word`, `meaning` and
`example`. Every text needs every app language. Ids are `<prefix>_<4 digits>` and must
be unique. Length limits are in `lib/data/content_schema.dart`. After editing, run
`dart run tools/validate_content.dart`. The tests run the same checks.

- **New item:** add it to the JSON file and run the validator.
- **New category:** add a JSON file, an entry in `ContentCatalog.categories`
  (`lib/data/content_models.dart`), its label and description in the ARB files, and
  their cases in `categoryLabel` / `Labels.categoryDescription` / `categoryIcon`.
- **New language:** add `lib/l10n/app_<code>.arb` (including `languageNativeName`),
  run `flutter gen-l10n`, and add the `<code>` text to every content item. The
  validator lists every missing one.

## Privacy

dailywall collects nothing and has no network access. See the
[privacy policy](docs/privacy-policy.md).

## License and credits

Code © Yusuf Ayçiçek. The fonts are under the SIL Open Font License. Their licenses
are shown in the app under About → Licenses.
