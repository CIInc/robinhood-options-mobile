# Investing Mobile

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
If prompted choose the ```Flutter``` configuration.

### Android Device

1. Enable USB debugging on your Android device.
2. Plug in your device. 
3. Open the command palette (```Ctrl+Shift+P```) and enter ```Flutter: Select Device```  
Or  
Navigate to the project directory and run the flutter command.
    ```bash
    cd src/robinhood_options_mobile
    flutter run
    ```

#### Debugging Notes

##### Wireless debugging

- On device, open Settings > System > Developer options.
    - Enable USB debugging & Wireless debugging.
- Connect device to computer over USB. Accept pairing notification on device.
- Open Android Studio > Tools > Device Manager and pair device.
- Run these commands to connect wirelessly:
    ```bash
    $ ${HOME}/AppData/Local/Android/Sdk/platform-tools/adb tcpip 5555
    restarting in TCP mode port: 5555
    $ ${HOME}/AppData/Local/Android/Sdk/platform-tools/adb connect 192.168.86.36
    connected to 192.168.86.36:5555
    ```
- Unplug device and start debugging.

### iOS Device

1. Enable developer on your iOS device.
2. Open ```Devices and Simulators``` window in XCode and ensure that your device is paired and connected. 
3. Open the command palette (```Ctrl+Shift+P```) and enter ```Flutter: Select Device```  
Or  
Navigate to the project directory and run the flutter command.
    ```bash
    cd src/robinhood_options_mobile
    flutter run --release
    ```

**Debugging Notes**
- For error `Exception: Error running pod install`, run the following commands:
    ```bash
    rm ./ios/Pods
    rm ./ios/Podfile.lock
    flutter clean
    flutter pub get
    flutter run
    ```

### Web

Select a browser from the device selector. *Note that this is not working due to CORS.*

### Emulator 

Select a mobile emulator from the device selector. *Note that this is not working due to ?*

## Install

### Device

1. Connect your Android device to your computer with a USB cable.
2. Navigate to the project directory and run the flutter command.
    ```bash
    cd src/robinhood_options_mobile
    flutter install
    ```

    The response should contain the following status message.

    ```bash
    Installing app.apk to Pixel 5...
    Uninstalling old version...
    Installing build\app\outputs\flutter-apk\app.apk...                 5.2s
    ```

## Generate Icons

1. Replace src/robinhood_options_mobile/icon.png with latest icon PNG image at the maximum possible resolution (1024x1024?).
2. Run `flutter pub run flutter_launcher_icons` in the project directory to generate all icons for iOS and Android.

## Publish

### Android

#### Build app bundle

```bash
cd src/robinhood_options_mobile
flutter build appbundle
```

#### Generate APKs

This command generates an .apk file used to publish an installation file.

```bash
cd src/robinhood_options_mobile
flutter build apk --release
```

### iOS

#### Build IPA

```bash
cd src/robinhood_options_mobile
flutter build ipa
```

#### Upload to App Store

1. Install [Transporter App](https://apps.apple.com/us/app/transporter/id1450874784)
2. Add ipa file from `./build/ios/ipa/`
3. `Verify` and `Deliver`

## Test

```bash
cd src/robinhood_options_mobile
flutter test
```

 