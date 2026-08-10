# TestFlight deployment

## One-time setup

1. In App Store Connect, open **Users and Access > Integrations > App Store
   Connect API** and create a key with the **App Manager** role.
2. Download the key. Apple only allows it to be downloaded once.
3. Save it as:

   ```text
   ~/.appstoreconnect/private_keys/AuthKey_YOUR_KEY_ID.p8
   ```

4. Copy `.testflight.env.example` to `.testflight.env` and fill in the key ID
   and issuer ID. `.testflight.env` and `AuthKey_*.p8` are ignored by Git.

## Deploy

From the Flutter project directory, run:

```sh
scripts/deploy_testflight.sh
```

The script increments the build number in `pubspec.yaml`, runs dependency
resolution, static analysis and tests, builds and validates the signed IPA, and
uploads it to App Store Connect. For a new app version:

```sh
scripts/deploy_testflight.sh --version 0.37.2
```

Use `--dry-run` to preview the version change or `--skip-upload` to build
without uploading. Run `scripts/deploy_testflight.sh --help` for all options.

The script ensures Flutter's ephemeral Swift package exists, then pre-generates
and resolves its release configuration before archiving. It deliberately does
not delete `ios/Flutter/ephemeral`: Xcode needs the local package to exist when
configuration begins. If Xcode still encounters its transient `Package.swift
was modified during the build` race, the archive step regenerates the package
and retries once. Other build failures are not retried or hidden.

If a build, validation, or upload fails, the script restores the previous
`pubspec.yaml` version. This lets you rerun the deployment without accidentally
consuming another build number.

The upload makes the build available in App Store Connect after Apple's
processing finishes. Internal TestFlight groups can receive it automatically
if automatic distribution is enabled. External testing still requires the
build to be submitted for TestFlight Beta App Review in App Store Connect.