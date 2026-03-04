# caoliao_ledger

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Android Release 签名配置

1. 生成 keystore（项目根目录执行）：

	```bash
	keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
	```

2. 复制 [android/key.properties.example](android/key.properties.example) 为 `android/key.properties`，并填入真实密码。

3. 构建 release APK：

	```bash
	flutter build apk --release
	```

4. 产物路径：`build/app/outputs/flutter-apk/app-release.apk`
