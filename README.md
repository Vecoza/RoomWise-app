# RoomWise

RoomWise is a single Flutter codebase that ships two apps:

- **Guest app (mobile):** hotel discovery, booking, and payment flow.
- **Admin app (desktop):** hotel administration panel.

## Entry points

- `lib/main.dart` → defaults to the **guest** app (`lib/main_guest.dart`)
- `lib/main_guest.dart` → **guest** app entry point
- `lib/main_admin.dart` → **admin** app entry point

## Prerequisites

- Flutter SDK installed
- Backend running (API is used by both guest and admin apps)

## Configuration

### API base URL

The app builds the API base URL in `lib/core/api/api_config.dart`:

- `ROOMWISE_API_HOST` (optional) via `--dart-define`
- Defaults:
  - Android emulator: `10.0.2.2`
  - iOS simulator / desktop / web: `localhost`

Examples:

```
flutter run -t lib/main_guest.dart --dart-define=ROOMWISE_API_HOST=192.168.1.20
```

### Stripe publishable key

The guest app loads the Stripe key in `lib/main_guest.dart`:

1. First tries assets: `.env` or `stripe.env` (both are listed in `pubspec.yaml`)
2. Fallback: `--dart-define=STRIPE_PUBLISHABLE_KEY=...`

## Run in 2 ways

1.  The project contains an **encrypted file**:
    fit-build-2026-01-13.zip

🔐 **Archive code:** `fit`

Inside the archive are:

- **Release/** – `.exe` file to launch the **desktop application**
- **flutter-apk/** – `.apk` file for testing the **mobile application**

This is the **fastest way** to test the application without additional configuration.

2.

Install dependencies:

```
flutter pub get
```

Guest (default):

```
flutter run -t lib/main_guest.dart
```

Admin (desktop):

```
flutter run -t lib/main_admin.dart -d macos
```

Use `windows` or `linux` for desktop targets on those platforms.

## Localization

Localization files live under `lib/l10n` and are generated via Flutter l10n:

- ARB templates: `lib/l10n/app_en.arb`, `lib/l10n/app_bs.arb`
- Generated output: `lib/l10n/app_localizations.dart`

## Admin access

- The admin app uses `AdminRootShell`, which gates access to the admin UI.
- A signed-in user must have the **Administrator** role to enter.

## Demo credentials

- Guest (seeded): vecaTest@gmail.com / VecaTest123! also vecolini1@gmail.com / Vecolini123!
- Admin: (seeded) admin1@roomwise.com / HotelAdmin123! admin[1-14]@roomwise.com / HotelAdmin123! The hotel with id 1 is assigned admin1 and so on until the hotel with id 14. For each created hotel with its id, admin[hotel id]@gmail.com is assigned.
