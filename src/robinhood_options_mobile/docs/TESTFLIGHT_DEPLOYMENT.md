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
scripts/deploy_testflight.sh --version 0.37.0
```

Use `--dry-run` to preview the version change or `--skip-upload` to build
without uploading. Run `scripts/deploy_testflight.sh --help` for all options.

The upload makes the build available in App Store Connect after Apple's
processing finishes. Internal TestFlight groups can receive it automatically
if automatic distribution is enabled. External testing still requires the
build to be submitted for TestFlight Beta App Review in App Store Connect.
