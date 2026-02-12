# Mobile CI/CD Setup

This document explains how to set up the necessary secrets for the GitHub Actions mobile build workflow (`.github/workflows/cd.yml`).

## iOS Setup

### Prerequisites

1.  A valid **iOS Distribution Certificate** (.p12).
2.  A **Distribution Provisioning Profile** (.mobileprovision) for the **Main App** that includes the **App Groups** capability (`group.com.robinhood_options_mobile`).
3.  A **Distribution Provisioning Profile** (.mobileprovision) for the **Portfolio Widget Extension** that also includes the **App Groups** capability.
4.  An **ExportOptions.plist** file configured for App Store or Ad-Hoc distribution.

### GitHub Actions Secrets (iOS)

| Secret Name | Description |
| :--- | :--- |
| `IOS_DISTRIBUTION_CERTIFICATE_BASE64` | Base64 encoded `.p12` distribution certificate. |
| `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` | The password for the `.p12` certificate. |
| `IOS_PROVISIONING_PROFILE_BASE64` | Base64 encoded `.mobileprovision` for the Main App. |
| `IOS_WIDGET_PROVISIONING_PROFILE_BASE64` | Base64 encoded `.mobileprovision` for the Widget Extension. |
| `IOS_EXPORT_OPTIONS_PLIST` | The raw content of your `ExportOptions.plist`. |

### How to encode iOS secrets

Run these commands on your macOS machine:

```bash
# Main App Provisioning Profile
base64 -i <path_to_app_profile>.mobileprovision | pbcopy

# Widget Extension Provisioning Profile
base64 -i <path_to_widget_profile>.mobileprovision | pbcopy

# Distribution Certificate
base64 -i <path_to_certificate>.p12 | pbcopy
```

### How to generate `ExportOptions.plist`

The easiest way for Flutter developers to generate a valid `ExportOptions.plist` is to run a local release build:

1.  Ensure your local Xcode is configured with the correct Provisioning Profiles.
2.  Run the following command from the `src/robinhood_options_mobile` directory:
    ```bash
    flutter build ipa --release
    ```
3.  Once the build completes, find the generated file at:
    `build/ios/ipa/ExportOptions.plist`
4.  Copy the raw XML content of that file and paste it into the `IOS_EXPORT_OPTIONS_PLIST` GitHub Secret.

---

## Android Setup

### Prerequisites

1.  An **Upload Keystore** (.jks) file.
2.  A `key.properties` file containing the keystore details.
3.  A **Google Play Service Account JSON** for automated Play Store uploads.

### GitHub Actions Secrets (Android)

| Secret Name | Description |
| :--- | :--- |
| `ANDROID_KEY_PROPERTIES` | The full content of your `android/key.properties` file. |
| `ANDROID_KEYSTORE_BASE64` | Base64 encoded `upload-keystore.jks` file. |
| `PLAY_STORE_UPLOAD_SERVICE_ACCOUNT_JSON` | The raw JSON key for the Google Play service account. |

### How to encode Android secrets

Run this command on your machine to encode the keystore:

```bash
# Upload Keystore
base64 -i <path_to_keystore>.jks | pbcopy
```

### `key.properties` Template

Your `ANDROID_KEY_PROPERTIES` secret should follow this format:

```properties
storePassword=your_keystore_password
keyPassword=your_key_password
keyAlias=upload
storeFile=upload-keystore.jks
```

---

## Troubleshooting

### iOS App Groups Error
`Provisioning profile "..." doesn't include the App Groups capability.`

This usually means the profile created in the Apple Developer Portal does not have the **App Groups** capability enabled. 
1. Go to **Identifiers** in the Apple Developer Portal.
2. Select your App ID (and Widget ID).
3. Ensure **App Groups** is checked and the specific group (`group.com.robinhood_options_mobile`) is associated.
4. Regenerate and download the Provisioning Profiles.

### iOS Extension Signing Conflict
`PortfolioWidgetExtension has conflicting provisioning settings... switching to manual signing in the Signing & Capabilities editor.`

This happens when CI forces manual signing for the project but the extension target is still set to "Automatic". The `cd.yml` workflow now automatically handles this by patching the `pbxproj` for both the main app and the extension, provided you have set the `IOS_WIDGET_PROVISIONING_PROFILE_BASE64` secret.

### Android Signing Error
Ensure the `keyAlias` and passwords in `ANDROID_KEY_PROPERTIES` exactly match those used when creating the keystore.
