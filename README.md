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

## Run

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
