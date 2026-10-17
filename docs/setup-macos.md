# macOS 开发环境与安卓 APK 打包

本文说明如何在 macOS（Apple 芯片或 Intel 均可）上搭建 Flutter 开发环境并打出安卓 APK。命令都针对国内网络配置了镜像。

> 以后在同一台 Mac 上也能编译 iOS 和 macOS 版本，那时再另外安装 Xcode。

## 空间预估

| 组件 | 大小（约） | 说明 |
|---|---|---|
| Flutter SDK | 2.5–3 GB | 必需 |
| Android SDK（命令行工具、platform-tools、build-tools、平台包） | 0.5–1 GB | 必需 |
| Android NDK | 1.5–2.5 GB | 部分插件构建时会自动下载 |
| Gradle 和 Maven 依赖缓存 | 1–2 GB | 首次构建时自动下载 |
| Dart 依赖包缓存（pub cache） | 0.3–1 GB | 必需 |
| 安卓模拟器和系统镜像 | 3–6 GB | 可选，用真机调试就不需要 |
| Xcode（以后做 iOS 和 macOS 版时） | 15–40 GB | 打 APK 不需要 |

只打 APK 大约需要 **6–9 GB**。

## 1. 基础工具

```bash
xcode-select --install          # 命令行开发工具（git、clang 等）
python3 --version               # 运行书稿预处理脚本需要 Python 3.10 或更高版本
```

安装 Homebrew。网络不好时可以改用清华镜像安装，参见 <https://mirrors.tuna.tsinghua.edu.cn/help/homebrew/>。

## 2. JDK

用 JDK 17（JDK 21 也可以）：

```bash
brew install --cask zulu@17
```

`zulu@17` 安装时需要输入管理员密码。没有密码或在非交互环境下，可以改用不需要 sudo 的 Homebrew 版本：

```bash
brew install openjdk@17
```

## 3. 环境变量（含国内镜像）

把下面几行追加到 `~/.zshrc`，然后执行 `source ~/.zshrc`：

```bash
# JDK
export JAVA_HOME="$(/usr/libexec/java_home -v 17 2>/dev/null || echo /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home)"

# Flutter 国内镜像
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"

# Flutter 与 Android SDK 路径
export FLUTTER_HOME="$HOME/development/flutter"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$FLUTTER_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
```

## 4. 安装 Flutter SDK

```bash
mkdir -p ~/development && cd ~/development
git clone -b stable https://github.com/flutter/flutter.git
# GitHub 访问慢时，也可以从 https://docs.flutter.cn/install/archive 下载 stable 版压缩包，解压到 ~/development/flutter
flutter --version              # 首次运行会通过上面配置的镜像下载 Dart SDK 和引擎文件
flutter config --no-analytics
```

## 5. 安装 Android SDK（不需要 Android Studio）

1. 从 <https://developer.android.google.cn/studio#command-line-tools-only> 下载 macOS 版 **Command line tools only** 压缩包。
2. 解压并放到指定位置（目录名必须是 `cmdline-tools/latest`）：

```bash
mkdir -p "$ANDROID_HOME/cmdline-tools"
cd ~/Downloads && unzip commandlinetools-mac-*_latest.zip
mv cmdline-tools "$ANDROID_HOME/cmdline-tools/latest"
```

3. 安装 SDK 组件并接受许可：

```bash
sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0"   # Flutter 3.47 起要求 Android SDK 36
flutter config --android-sdk "$ANDROID_HOME"
flutter doctor --android-licenses      # 全部输入 y
flutter doctor                          # Android toolchain 一项应显示 ✓
```

> 构建时如果提示缺少其他平台版本或 NDK，Gradle 会自动下载，前提是已经接受过许可。

## 6. Gradle 国内镜像（项目创建后配置一次，`app/` 已配置）

`flutter create` 生成的安卓工程默认从 Google 和 Maven Central 下载依赖。国内网络下建议做下面两处修改。

**`android/gradle/wrapper/gradle-wrapper.properties`**：把下载地址换成腾讯云镜像，版本号保持文件里原有的不变：

```properties
distributionUrl=https\://mirrors.cloud.tencent.com/gradle/gradle-8.x-all.zip
```

**`android/settings.gradle.kts`**（`pluginManagement` 和 `dependencyResolutionManagement` 两处），以及 **`android/build.gradle.kts`**（`allprojects`）：在 `repositories` 的最前面加上阿里云镜像：

```kotlin
repositories {
    maven("https://maven.aliyun.com/repository/google")
    maven("https://maven.aliyun.com/repository/public")
    maven("https://maven.aliyun.com/repository/gradle-plugin")
    google()
    mavenCentral()
}
```

## 7. 打包 APK

App 工程在仓库的 `app/` 目录，第 6 步的 Gradle 镜像已经配置好。打包前先把书稿同步成 App 资源：

```bash
python3 tools/build_books.py           # 重新生成 books/ 下的 JSON 和书目
python3 app/tool/sync_books.py         # 打包到 app/assets/data/，并刷新 pubspec.yaml 的 assets 清单
cd app
flutter pub get
flutter build apk --release --split-per-abi
```

生成的文件在 `app/build/app/outputs/flutter-apk/`：

- `app-arm64-v8a-release.apk`：适用于绝大多数近年的安卓手机
- `app-armeabi-v7a-release.apk`：适用于较老的 32 位手机

如果想打一个通用包（体积较大），去掉 `--split-per-abi` 即可，输出文件是 `app-release.apk`。

安装到手机有两种方式：

- 把 APK 文件传到手机上直接安装（需要允许「安装未知来源应用」）。
- 用 USB 连接，并在手机上开启 USB 调试，然后运行：

```bash
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## 8. 正式签名（发布前）

模板工程的 release 包默认使用调试密钥签名，只适合自己测试。对外分发前要生成正式密钥：

```bash
keytool -genkey -v -keystore ~/taintedview-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias taintedview
```

然后新建 `app/android/key.properties`，并在 `app/android/app/build.gradle.kts` 里配置 `signingConfigs`，参见 <https://docs.flutter.cn/deployment/android>。

**密钥文件和 `key.properties` 不要提交到仓库**。密钥一旦丢失，就无法再给已安装的用户推送更新。

## 9. 可选：安卓模拟器

```bash
sdkmanager "emulator" "system-images;android-35;google_apis;arm64-v8a"   # Intel Mac 把 arm64-v8a 换成 x86_64
avdmanager create avd -n pixel35 -k "system-images;android-35;google_apis;arm64-v8a" -d pixel_7
flutter emulators --launch pixel35
cd app && flutter run
```

## 常见问题

| 现象 | 处理方法 |
|---|---|
| `flutter doctor` 提示 cmdline-tools component is missing | 确认目录是 `$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager` |
| Gradle 卡在 `Downloading https://services.gradle.org/...` | 按第 6 步修改 `distributionUrl` |
| `Could not resolve com.android.tools.build:gradle` | 按第 6 步添加阿里云 Maven 镜像 |
| `flutter pub get` 很慢或超时 | 检查 `PUB_HOSTED_URL`、`FLUTTER_STORAGE_BASE_URL` 是否生效（`echo $PUB_HOSTED_URL`） |
| 提示 JDK 版本不兼容 | `flutter config --jdk-dir "$(/usr/libexec/java_home -v 17)"` |
