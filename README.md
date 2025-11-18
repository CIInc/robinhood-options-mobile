# RealizeAlpha

This repository implements brokerage APIs like Robinhood to provide an options focused Android and iOS mobile app using the Flutter SDK.

## Getting Started

See our [docs](https://ciinc.github.io/robinhood-options-mobile/) for use cases and application requirements.

## Features

*   **Brokerage Integration:** Connects securely to brokerage accounts (e.g., Robinhood) to fetch real-time data.
*   **Options Chain Viewing:** Displays detailed options chains for various underlying assets.
*   **Historical Data Analysis:** Fetches and visualizes historical price data for instruments.
*   **Stock Screener:** Advanced stock filtering by sector, market cap, P/E ratio, dividend yield, price, and volume with quick presets and Yahoo Finance integration.
*   **Trade Signals:** AI-powered agentic trading with multi-indicator correlation system (price patterns, RSI, market direction, volume) for automatic trade detection and execution. Supports both daily and intraday signals (15-minute, hourly, and daily intervals).
*   **AI-Powered Insights:** Leverages Generative AI (like Gemini) to provide analysis on market data (e.g., chart trends).
*   **Investor Groups:** Create and join investor groups to share portfolios and collaborate with other investors. Support for both public and private groups with admin controls.
*   **Cross-Platform:** Built with Flutter for a consistent experience on both Android and iOS.


## Architecture Overview

RealizeAlpha utilizes a combination of technologies:

*   **Mobile App:** Developed using the Flutter SDK and Dart for cross-platform deployment (iOS, Android).
*   **Backend Services:** Firebase Functions (written in TypeScript/JavaScript) are used for:
    *   Securely interacting with brokerage APIs.
    *   Handling business logic that shouldn't reside on the client.
    *   Integrating with AI services (e.g., Google AI Gemini API).
*   **Authentication:** Firebase Authentication manages user sign-in and security.
*   **Database/Storage:** Firestore or other Firebase services might be used for storing user preferences or other relevant data (if applicable).
*   **Hosting:** Firebase Hosting is used for deploying web-related components or documentation sites.


### Latest Release

- [RealizeAlpha | Apple App Store](https://testflight.apple.com/join/ARmsGSN8): TestFlight only, production release coming soon.
- [RealizeAlpha | Google Play Store](https://play.google.com/apps/internaltest/4701722902176245187): Internal testing only, production release coming soon.

<!--
## Usage

TODO
-->

## Build

### Dependencies

In order to build and debug locally, you must install the following dependencies:

- Android Studio (for Android deployment)
- XCode (for iOS deployment)
- Flutter SDK
- VS Code
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
    flutter run --release
    ```

**Debugging Notes**
- For error `Exception: Error running pod install`, run the following commands:
    ```bash
    rm -rf ./ios/Pods;rm ./ios/Podfile.lock;flutter clean;flutter pub get
    flutter build ios
    # or flutter run
    ```

    If that doesn't work try a pod repo update.
    ```bash
    cd ios
    pod repo update
    flutter build ios
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
    flutter install
    ```

    The response should contain the following status message.

    ```bash
    Installing app.apk to Pixel 5...
    Uninstalling old version...
    Installing build\app\outputs\flutter-apk\app.apk...                 5.2s
    ```

## Maintain

### Upgrade dependencies

#### Flutter upgrades

To ensure you are using the latest packages, run these commands to check and upgrade them: 
```bash
flutter pub outdated
flutter pub upgrade --major-versions
flutter pub upgrade --tighten
```

#### Firebase upgrades

Run these commands in both `functions` and `firebase` folders for Firebase function deployment and running admin tools respectively.
```bash
npm install -g npm-check-updates
ncu -u
npm install
```

### Generate App Icons & Launch Images

1. Replace src/robinhood_options_mobile/icon.png with latest icon PNG image at the maximum possible resolution (1024x1024?).
2. Run `dart run flutter_launcher_icons` in the project directory to generate all icons for iOS and Android.
3. Run `dart run flutter_native_splash:create` in the project directoru to generate all splash screens for iOS, Android and Web.

### Linting (javascript & typescript)

To fix issues with code formatting such as:
> 10 errors and 0 warnings potentially fixable with the `--fix` option.
> Error: functions predeploy error: Command terminated with non-zero exit code 1

Run the following command in the `functions` directory.

```bash
npm run lint -- --fix
```

_You can do this automatically in VS Code by installing the eslint plugin._

### Manage Firebase Auth Claims

#### Change a user role to admin

- Download Service Account private key from [https://console.firebase.google.com/project/realizealpha/settings/serviceaccounts/adminsdk](https://console.firebase.google.com/project/realizealpha/settings/serviceaccounts/adminsdk)
- Open `src/firebase-admin.js` Node.js file.
    - Change the path of the downloaded file at the following line: `var serviceAccount = require("/Users/aymericgrassart/Downloads/realizealpha-firebase-adminsdk-uzw9z-7a694c5249.json");`
    - Change the id of the user that you want to add the role to at the following line.
        ```js
        admin.credential.setCustomUserClaims('exKIqutDIgWmPs6FDXEWMHJYdam1', {
            role: 'admin'
        });
        ```
- Save and execute the Node.js script from the src folder.
    ```bash
    node firebase-admin.js
    ```

## Publish

### Firebase Hosting

`firebase.json` was changed to modify the `hosting` property `"source": "."` to `"public": "build/web"` in order to deploy custom builds.

```bash
#flutter build web --web-renderer html
flutter build web --release
firebase deploy --only hosting
```

Previously, the public folder was deployed with this configuration:
```json
{
  "hosting": {
    "public": "public",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
}
```

### Firebase Functions

Functions will automatically deploy with hosting deployments with `firebase deploy`. To deploy only the functions, use the following command.

```bash
firebase deploy --only functions
```

The following secrets should be configured to prevent storing sensitive passwords and tokens in source control.

```bash
# Change the value of an existing secret
firebase functions:secrets:set GEMINI_API_KEY
# View the value of a secret
firebase functions:secrets:access GEMINI_API_KEY
```

### Firebase Firestore

To deploy the Firestore rules and indexes, use the following command.

```bash
firebase deploy --only firestore
```

### Android Play Store

#### Build app bundle

```bash
flutter build appbundle --release
```

#### Generate APKs

This command generates an .apk file used to publish an installation file.

```bash
flutter build apk --release
```

### Apple App Store

#### Build IPA

```bash
flutter build ipa --release
```

If you get an error, see Debugging Notes section above to clean the project.

#### Upload to App Store

1. Install [Transporter App](https://apps.apple.com/us/app/transporter/id1450874784)
2. Add ipa file from `./build/ios/ipa/`
3. `Verify` and `Deliver`

## Test

```bash
flutter test
```
