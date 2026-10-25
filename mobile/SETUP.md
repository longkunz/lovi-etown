# 🎉 Welcome to flutter_starter!

This project was generated dynamically based on your specific requirements. Before running your app for the first time, follow this brief setup guide to configure the required environment variables, permissions, and dependencies locally.

---

## 1. 📱 Platform folders (web download only)

The web wizard ZIP does **not** include native runners (`android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`). Those are created only via the Flutter CLI.

Skip this step if you generated the project with the FlutterInit CLI (`flutter create` already ran).

From the project root:
```bash
flutter create . --project-name flutter_starter --org com.example
```

This adds the platform folders without overwriting your generated Dart sources.

---

## 2. 📦 Initial Dependencies & Generation

First, fetch all pub packages, then format the generated Dart (templates are not pre-formatted):
```bash
flutter pub get
dart format .
```

### Code Generation
*(No initial code generation required for your main stack)*

### Localization
Since you chose to include `easy_localization`, run these commands whenever you add or modify string translations to generate your keys correctly:
```bash
flutter pub run easy_localization:generate -S assets/translations -O lib/src/core/i18n -o locale_keys.g.dart
```

---

## 3. 🎨 Native Splash Screen Setup

This project uses `flutter_native_splash`.

**To apply your custom app launch screen:**
1. Place your transparent splash logo at [`assets/images/splash.png`](assets/images/splash.png).
2. Open [`flutter_native_splash.yaml`](flutter_native_splash.yaml) in the root of your project.
3. Uncomment the `image:` paths so it looks like:
   ```yaml
   flutter_native_splash:
     color: "##fafafa"
     image: assets/images/splash.png
     android_12:
       image: assets/images/splash.png
       icon_background_color: "##fafafa"
   ```
4. Apply the native configuration natively by running:
```bash
dart run flutter_native_splash:create --path=flutter_native_splash.yaml
```
*Note: Run this command every time you change your splash image or background color.*

---

## 4. 🔐 App Permissions (Android & iOS)

Based on your chosen flags (e.g.  , Geolocator ), you must configure Native permissions before testing these features.

### Android Setup
Open [`android/app/src/main/AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml) and add the following required permissions inside the `<manifest>` tag, directly above the `<application>` block:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Internet is standard and required -->
    <uses-permission android:name="android.permission.INTERNET" />
    
    <!-- Required for geolocator -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

### iOS Setup 
First, describe why you need permissions. Open [`ios/Runner/Info.plist`](ios/Runner/Info.plist) and add the following inside the main `<dict>` block:

```xml
<dict>
    ...
    <!-- Required for geolocator -->
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>This app requires access to location to provide localized content.</string>
    <key>NSLocationAlwaysUsageDescription</key>
    <string>This app requires access to location in the background.</string>
</dict>
```

**IMPORTANT: Podfile Configuration**
Since you've enabled `permission_handler`, you **MUST** configure your requested iOS permissions using Podfile macros to comply with App Store rules. 

Open [`ios/Podfile`](ios/Podfile), find the `post_install` block at the bottom, and replace it completely with this snippet:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)

    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',

        ## dart: PermissionGroup.camera
        'PERMISSION_CAMERA=0',

        ## dart: PermissionGroup.photos
        'PERMISSION_PHOTOS=0',

        ## dart: PermissionGroup.location
        'PERMISSION_LOCATION=1',
        'PERMISSION_LOCATION_WHENINUSE=1',

        ## dart: PermissionGroup.mediaLibrary
        'PERMISSION_MEDIA_LIBRARY=0',

        ## dart: PermissionGroup.microphone (Usually 1 if video recording is active with image_picker)
        'PERMISSION_MICROPHONE=0',

        ## Unused permissions forcefully disabled to avoid App Store Rejection
        'PERMISSION_EVENTS=0',
        'PERMISSION_EVENTS_FULL_ACCESS=0',
        'PERMISSION_REMINDERS=0',
        'PERMISSION_CONTACTS=0',
        'PERMISSION_SPEECH_RECOGNIZER=0',
        'PERMISSION_NOTIFICATIONS=0',
        'PERMISSION_SENSORS=0',
        'PERMISSION_BLUETOOTH=0',
        'PERMISSION_APP_TRACKING_TRANSPARENCY=0',
        'PERMISSION_CRITICAL_ALERTS=0',
        'PERMISSION_ASSISTANT=0',
      ]
    end
  end
end
```

---

## 5. 🌍 Environment Variables & Google Maps API Key

Your project relies on `flutter_dotenv` to load app-level secrets, and native configuration for Google Maps SDK (T18).

### 5.1 App Variables (`.env`)
1. Create a [`.env`](.env) file in the `mobile/` project root folder.
2. Copy the variables from `.env.example`, use `CAMERA_API_BASE_URL=https://api.capyai.site`, and set `CAMERA_READER_KEY` to your reader API key. Keep `CAMERA_DEMO_MODE=false` for the real backend.
3. For Dart reference, optional: `GOOGLE_MAPS_API_KEY=AIzaSy...`.

The app loads `.env` automatically at startup. Explicit `--dart-define` values override individual `.env` values. Stop and restart the app after changing these values.

### 5.2 Google Maps SDK (Traffic Layer & Camera Locations)
Maps SDK for Android and iOS requires native API Key registration:
1. **Google Cloud Console:** Create a project, enable **Maps SDK for Android** and **Maps SDK for iOS**.
2. **Key Restriction:**
   - Android: Restrict by package name `com.lovisoft.etown` and debug/release SHA-1 fingerprint.
   - iOS: Restrict by iOS bundle identifier `com.lovisoft.etown`.
3. **Android Configuration:**
   - Add to `mobile/android/local.properties`:
     ```properties
     GOOGLE_MAPS_API_KEY=AIzaSyYourActualKeyHere
     ```
   - Or export `export GOOGLE_MAPS_API_KEY=AIzaSy...` in your build environment.
   - The key is injected at build time into `AndroidManifest.xml` via `manifestPlaceholders`.
4. **iOS Configuration:**
   - Set `GOOGLE_MAPS_API_KEY` in your environment or Xcode build settings / `Info.plist`.
   - Pass API Key to `GMSServices.provideAPIKey("...")` in `AppDelegate.swift`.

---

## 6. 💾 Local Storage (Hive)

*(No local storage (Hive) selected for this project)*

---

## 7. ☁️ Backend Connections

You chose to structure your APIs using **Custom Backend**.

Camera connections automatically read `CAMERA_API_BASE_URL`, `CAMERA_READER_KEY`, and `CAMERA_DEMO_MODE` from `.env` at startup. Explicit `--dart-define` values override individual `.env` values. Run `flutter run` or select the `App: Production API` VS Code launch profile. Stop and restart the app after changing these values.

---

## 8. 🚀 Running the App

Once everything above is verified:

1. **For iOS Simulators/Devices**, map your native pods locally:
```bash
cd ios
pod install
cd ..
```

2. Run your app via VS Code, Android Studio, or CLI:
```bash
flutter run
```

Congratulations, and happy coding!
