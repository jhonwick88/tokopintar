# TokoPintar Build Rules

## Android APK Compilation
When building the Android APK for release, ALWAYS use `--split-per-abi`:
```bash
flutter build apk --release --split-per-abi
```
Do NOT build universal APK unless explicitly requested.

## Android App Bundle (AAB) Compilation
When building the Android App Bundle for release:
```bash
flutter build appbundle --release
```

## Windows Desktop Compilation
When building Windows release:
```bash
flutter build windows --release
```
