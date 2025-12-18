# roomwise

Roomwise is a single Flutter codebase that ships two apps:

- **Guest app (mobile):** hotel discovery + booking flow.
- **Admin app (desktop):** admin panel (separate UI).

## Entry points

- `lib/main.dart` → defaults to the **guest** app (`lib/main_guest.dart`)
- `lib/main_admin.dart` → **admin** app entry point

## Run

Guest (default):

- `flutter run`
- or explicitly `flutter run -t lib/main_guest.dart`

Admin (desktop):

- `flutter run -t lib/main_admin.dart -d macos` (or `windows` / `linux`)

## Notes

- The admin UI is currently a placeholder `AdminRootShell` that requires an
  authenticated user with the **Administrator** role.
