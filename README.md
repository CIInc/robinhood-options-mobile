# Robinhood Options Mobile

This repository implements the Robinhood API to provide an options focused Android and iOS mobile app using the Flutter SDK.

## Getting Started

See our [docs](https://ciinc.github.io/robinhood-options-mobile/) for use cases and application requirements.

<!--
## Usage

TODO
-->

## Build

### Dependencies

In order to build and debug locally, you must install the following dependencies:

- Android Studio (includes SDK Manager)
- VS Code
- Flutter SDK (includes Dart SDK)
- Dart & Flutter VS Code extensions

To ensure your installation was successful, run this command: 
```
flutter doctor -v
```

Once you see a "No issues found!" message, you are ready to start running the application.  

## Run & Debug

In VS Code, ```F5``` key, the ```Run``` icon, or from the ```Run``` menu to start debugging.
If prompted choose the ```Dart & Flutter``` configuration.

### Mobile (Android and iOS)

- Enable USB debugging on your Android device.
- Plug in your device. 
- Open the command palette (```Ctrl+Shift+P```) and enter ```Flutter: Select Device```

### Web

Select a browser from the device selector.

### Emulator 

Select a mobile emulator from the device selector.

## Publish

### Build app bundle

```
cd src/robinhood_options_mobile
flutter build appbundle
```

### Generate APKs

[Generate APKs using the offline bundle tool](https://flutter.dev/docs/deployment/android#offline-using-the-bundle-tool)

```cmd
"C:\Program Files\Java\jdk-15.0.2\bin\java" -jar bundletool-all-1.5.0.jar  build-apks --bundle=src\robinhood_options_mobile\build\app\outputs\bundle\release\app-release.aab --output=src\robinhood_options_mobile\build\app\outputs\bundle\release\app-release.apks

"C:\Program Files\Java\jdk-15.0.2\bin\java" -jar bundletool-all-1.5.0.jar install-apks --apks=src\robinhood_options_mobile\build\app\outputs\bundle\release\app-release.apks 
```

## Test

TODO
 