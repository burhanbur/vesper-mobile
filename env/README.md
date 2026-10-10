# Application environment

In debug/profile mode, the application loads these JSON assets at startup when
no explicit `API_BASE_URL` compile-time value is provided. Android uses
`development.json`; browser and desktop use `web.json`.
Release builds require `--dart-define-from-file` explicitly and never fall back
to a development URL. Explicit compile-time values override the assets.

- `development.json`: Android emulator (`10.0.2.2` reaches the host computer).
- `web.json`: browser or desktop development (`localhost`).

Run outside VS Code using `flutter run --dart-define-from-file=env/development.json`.
For web, use `flutter run -d chrome --dart-define-from-file=env/web.json`.
VS Code launch configurations only select a file; URLs are configured here.
For a physical device, set the development URL to the computer's LAN address.
The backend must be reachable and the URL must include `/api/v1`.

Stop and relaunch after changing values; hot reload/restart cannot replace
compile-time environment definitions. Release/profile launches must receive an
appropriate environment file explicitly; no production URL is assumed.

These values are public application configuration, not secrets. Never put API
keys, passwords, or tokens in these files: compiled application configuration can
be inspected by users.
