# CineNow 🎬

A cinematic movie-reservation app for Android, built with **Flutter**, **Firebase Authentication** (email/password) and **Firebase Realtime Database**.

Browse films → movie details → cinema & showtime → live seat map → review → confirmation → digital ticket.
Browsing works without an account; sign-in is requested only when you confirm, and your selection is kept while you do.

> Reservations are a demo — no payment is taken, and the QR code on tickets is decorative ("DEMO · Not valid for entry").

---

## What's inside

| Area | Highlights |
| --- | --- |
| Design system | Charcoal / warm-white / coral tokens, Sora + Inter (bundled, works offline), 4-pt spacing, motion tokens — `lib/core/theme/` |
| Screens | Welcome, Sign in / Sign up / Forgot password, Home, Explore, Movie details, Showtimes, Seat map, Review, Confirmation, My Tickets, Ticket detail, Profile — `lib/screens/` |
| Reusable widgets | Buttons, poster images with fallback art, seat map, ticket card, empty / error / offline states — `lib/widgets/` |
| Data | Plain-Dart models (`lib/models/`), Firebase + demo services behind one interface (`lib/services/`), Riverpod state (`lib/state/`) |
| Database | `firebase/database.rules.json`, `firebase/database.seed.json` |
| Tests | `test/` (unit + widget + demo mode), `tool/rules_test/` (security rules), `test_screens/` (screen renders) |

### Booking integrity
Tapping seats never writes to the database. On **Confirm Reservation** the app sends **one atomic multi-path update** that writes every seat (`occupiedSeats/{showtime}/{seat}`) *and* the reservation (`reservations/{uid}/{id}`). The security rules reject any seat that already exists, so either everything is saved or nothing is. If seats were taken in the meantime, the app names them, keeps your other seats, and returns you to the seat map. Seat availability also updates live while you choose and review.

> Why not `runTransaction()`? A Realtime Database transaction covers a single node, and rules can't stop a parent-level transaction from deleting other people's seats. The rule-checked multi-path update gives the same all-or-nothing guarantee and is enforced on the server.

---

## Run it

The app is already connected to the Firebase project **`cinenow-kmutnb-2026`** (owner: s6707012660018@email.kmutnb.ac.th). Auth (Email/Password), the Realtime Database (Singapore), the rules and the sample data are already set up.

```bash
flutter pub get
flutter run
```

Install on a phone: `flutter build apk --release --split-per-abi`, then install `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

### Modes

| Command | Data source |
| --- | --- |
| `flutter run` | Live Firebase project |
| `flutter run --dart-define=USE_EMULATORS=true` | Local Firebase Emulator Suite (see below) |
| `flutter run --dart-define=FORCE_DEMO=true` | **Demo mode** — bundled sample data, accounts and tickets stay on the device |

If the Firebase configuration is missing or Firebase can't start, the app falls back to demo mode automatically. An amber banner says so, and the success messages say "saved on this device (demo)", never "saved to Firebase".

---

## Firebase setup (for a new project or another machine)

You only need this if you want your own Firebase project.

1. **Create the project.** In the [Firebase console](https://console.firebase.google.com/), add a project.
2. **Authentication.** Go to Build → Authentication → Get started → **Email/Password** → Enable.
3. **Realtime Database.** Go to Build → Realtime Database → Create database. Pick a location (Singapore for Thailand) and start in **locked mode**.
4. **Connect the app.** Install the [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup), then from this folder run:
   ```bash
   firebase login
   dart pub global run flutterfire_cli:flutterfire configure --project=<your-project-id> --platforms=android --android-package-name=com.cinenow.app
   ```
   This rewrites `lib/firebase_options.dart` and `android/app/google-services.json`, which are the two files that connect the app.
5. **Deploy the rules, enable Email/Password, and load the sample data.** Update `.firebaserc` with your project ID, then:
   ```bash
   firebase deploy --only database,auth
   firebase database:set / firebase/database.seed.json
   ```
   Console alternative: Realtime Database → ⋮ → Import JSON → choose `firebase/database.seed.json`; then paste `firebase/database.rules.json` into the **Rules** tab and Publish.

### Refreshing showtimes
The seed holds 21 days of showtimes starting on its generation date. To roll them forward without touching users or reservations:

```bash
dart run tool/generate_seed.dart --refresh            # writes firebase/database.refresh.json
firebase database:update / firebase/database.refresh.json
```

Use `--days 30` or `--from 2026-11-01` to change the range. The catalog itself (movies, cinemas, seat layouts, prices, daily programmes) lives in `assets/seed/catalog.json`.

---

## Database structure

```
config                      app settings (booking fee, max seats, cities)
movies/{movieId}            title, genres, rating, durationMin, ageRating, synopsis, posterUrl, backdropUrl, cast[], status, releaseDate
cinemas/{cinemaId}          name, city, area, address, formats[], halls{hallId: {name, layoutId, format}}
layouts/{layoutId}          rows[{label, seats, type: standard|deluxe, aisleAfter[]}]
showtimes/{movieId}/{id}    cinemaId, hallId, format, date, time, startsAt, priceStandard, priceDeluxe, soldOut
occupiedSeats/{id}/{seat}   uid, reservationId, bookedAt (server time)
reservations/{uid}/{resId}  ref, movie/cinema snapshot, showtimeId, seats{E7: true}, prices, total, createdAt
users/{uid}                 displayName, email, city, createdAt
```

**Security rules**:
- Anyone can read the catalog and seat availability.
- Nobody can edit the catalog from the app.
- A seat can be claimed only by a signed-in user, only if it's free, and only together with their own matching reservation in the same write. A claimed seat can never be released or reassigned.
- Users can read and write only their own profile and reservations, and reservations are write-once.

---

## Tests

```bash
flutter analyze
flutter test                                  # unit, widget, demo-mode tests
flutter test test_screens --update-goldens    # renders key screens to test_screens/goldens/*.png
```

Security-rule tests (13 cases: double-booking, partial writes, spoofed owners, fake timestamps, privacy…) run against the local emulators:

```bash
firebase emulators:start --only auth,database          # needs Java 11+ (Android Studio's JBR works)
cd tool/rules_test && npm install && npm test
```

### Local emulator testing
- Run the app with `--dart-define=USE_EMULATORS=true`. The Android emulator reaches your PC at `10.0.2.2`. Debug and profile builds allow plain HTTP to it; release builds don't.
- Load sample data into the emulator: `curl -X PUT -H "Authorization: Bearer owner" --data-binary @firebase/database.seed.json "http://127.0.0.1:9000/.json?ns=cinenow-kmutnb-2026-default-rtdb"`.
- Throwaway emulator-only accounts are listed in `firebase/emulator-test-accounts.json`.
- Known quirk: the local Database emulator drops the app's socket about 60s after it connects. The app shows "Connection lost" and reconnects automatically when you confirm. The live database doesn't do this.

---

## Customising
- **Colours, type, spacing, motion:** `lib/core/theme/`
- **Movies, cinemas, halls, prices:** `assets/seed/catalog.json`, then regenerate the seed
- **Booking fee and seat limit:** the `config` node, or `CatalogConfig` defaults
- **App name and icon:** `android/app/src/main/AndroidManifest.xml` and `android/app/src/main/res/`

## Credits
Film data and images come from [TMDB](https://www.themoviedb.org/). This product uses the TMDB API but is not endorsed or certified by TMDB. Synopses are original; the cinemas are fictional. The fonts are Sora and Inter, under the SIL Open Font License.
