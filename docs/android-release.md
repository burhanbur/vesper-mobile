# Android release

## Identity and version

- Application ID / namespace: `id.bmafazi.vesper`.
- Launcher name: `Vesper`.
- First release version: `1.0.0+1` in `pubspec.yaml`.
- Increment the build number (`+2`, `+3`, ...) for subsequent Play uploads.
- Launcher icons and native splash use the existing `assets/images/logo.png`.
  Regenerate them on Windows with `powershell -ExecutionPolicy Bypass -File scripts/generate-android-branding.ps1`.

Changing the old `com.example.vesper_mobile` ID creates a separate Android app.
Existing installations and their local encrypted data are not migrated by this
change. Do not uninstall the old app or clear its data while it has unsynced work.

## Upload signing key

Release builds use `android/key.properties`; debug signing is never a fallback.
Debug/profile builds do not require release credentials.

The initial setup generated these **local, Git-ignored** files:

- `android/keystores/upload-keystore.jks`: RSA 2048-bit upload key,
  alias `vesper-upload`, certificate subject `CN=Vesper`.
- `android/key.properties`: keystore path and generated passwords.

Back up both files in secure storage outside this computer before publishing.
Do not commit or share them, and reuse the upload key for subsequent uploads.
On another workstation/CI, provision the files from secure storage; use
`android/key.properties.example` as the configuration reference. `storeFile`
is relative to `android/`, with forward slashes supported on Windows.
Enable Play App Signing when setting up the app in Play Console.

If starting a fresh project without an existing key, generate one interactively
with the JDK `keytool` (do not overwrite an existing upload key):

```powershell
keytool -genkeypair -v -keystore android/keystores/upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias vesper-upload
```

Then copy `android/key.properties.example` to `android/key.properties` and enter
the matching passwords. Never put passwords in shell command arguments or logs.

## Production API

The production domain is not configured yet. From the project root:

```powershell
Copy-Item env/production.example.json env/production.json
```

Replace `API_BASE_URL` with the full actual endpoint:

```json
{
  "API_BASE_URL": "https://api.YOUR_REAL_DOMAIN/api/v1"
}
```

The URL is public configuration; no API secret/token belongs here. Never ship
the placeholder URL. Gradle rejects empty URLs, HTTP, localhost/emulator hosts,
`.invalid` placeholders, credentials, query strings, fragments, and missing
`/api/v1`. Startup also validates explicit configuration. The check does not
verify API reachability or deploy the backend.

The release manifest enables internet access and disables cleartext traffic.
Debug/profile manifests allow local HTTP development.

## Validate and build

```powershell
flutter analyze
flutter test
flutter build appbundle --release --dart-define-from-file=env/production.json
```

Upload artifact: `build/app/outputs/bundle/release/app-release.aab`.
For a physical-device smoke test:

```powershell
flutter build apk --release --dart-define-from-file=env/production.json
```

Install the signed APK and check API access, login, offline writes, sync, app
lock, launcher icon, and cold-start splash on a physical device before uploading.
The automated build validation in this setup uses a reserved `.test` hostname;
its artifacts are moved to `build/release-validation/` and must not be published.

References: [Flutter Android deployment](https://docs.flutter.dev/deployment/android),
[Android app signing](https://developer.android.com/studio/publish/app-signing).
