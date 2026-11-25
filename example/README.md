# AdShift Flutter plugin example

A small app that calls the main parts of the plugin and prints what comes back.

```sh
flutter run --dart-define=ADSHIFT_API_KEY=<your key>
```

The example runs in test mode: its traffic stays out of your reports.

To try links, replace `example.rightlink.me` and the `adshiftexample` scheme in
`android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist` with your
own RightLink subdomain and scheme. On iOS, Universal Links also need the
Associated Domains capability (`applinks:<your domain>`).

`flutter test integration_test` checks the platform bridge on a device or
simulator without starting the SDK.
