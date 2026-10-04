# QSLMM

Flutter Android 移动端控制台，用于连接 [BH2VSQ/QSLCard-Manager](https://github.com/BH2VSQ/QSLCard-Manager)。

## 基本信息

- Android 应用显示名称：**QSLMM**
- Android Android Application ID / 包名：**`cn.bh2vsq.qslmanager`**
- UI：专业移动控制台风格
- 主色：`#5BCFFA` / `#F5ABB9` / `#FFFFFF`
- 支持：白天 / 夜间模式

## 主要功能

- 概览：QSO、QSL 状态、最近活动
- 日志：搜索、ADIF 导入、完整详情、编辑、QSL 编号颁发
- QSL：QSL 编号搜索、扫码搜索、详情、关联日志、补打
- 扫码：QSL 收发状态处理
- 地址簿：联系人维护、FROM / TO 地址标签推送
- 设置：服务器地址、连接诊断、显示模式

移动端不显示打印队列，但 QSL/地址标签任务仍按服务器 API 推送到 QSLCard-Manager 的打印系统。

## 开发环境

建议使用已安装 Flutter SDK 的 Windows/macOS/Linux 开发环境。

安装依赖：

```bash
flutter pub get
```

## Android 配置

本源码包包含 Flutter/Dart 源码和图标资源。若仓库中尚未生成 Android 主机目录：

```powershell
flutter create . --platforms=android
```

然后应用 Android 包名与应用名称配置：

```powershell
.\tool\configure_android_branding.ps1
```

脚本会将：

```text
Application ID / Namespace
cn.bh2vsq.qslmanager

应用显示名称
QSLMM
```

并调整 `MainActivity` 的 Kotlin/Java 包路径。

## 应用图标

项目中的官方应用图标位于：

```text
assets/icon/qslmm_icon.png
```

Android Launcher Icon 资源已经随源码提供，不依赖额外图标生成命令。执行 Android 品牌配置脚本时会自动把图标复制到 `android/app/src/main/res/mipmap-*`。

## 运行

```bash
flutter run
```

## 构建 Release APK

```bash
flutter clean
flutter pub get
flutter build apk --release
```

生成文件通常位于：

```text
build/app/outputs/flutter-apk/app-release.apk
```

## 服务器地址

默认 API：

```text
http://10.0.2.2:7055/api
```

Android 模拟器访问宿主机时可使用 `10.0.2.2`；真机请填写 QSLCard-Manager 所在设备的局域网地址，例如：

```text
http://192.168.2.209:7055/api
```

APP 会自动规范服务器地址并请求：

```text
http://192.168.2.209:7055/api/health
```

## 发布到 GitHub

不要将以下文件提交到公开仓库：

```text
android/key.properties
*.jks
*.keystore
*.p12
```

如果使用个人签名 keystore，请将其保存在仓库之外。

## 服务端职责

QSLMM 不复制服务端业务规则。打印队列、地址标签模板、QSL 编号、库存状态等业务逻辑由 QSLCard-Manager 服务端负责。


## 应用内检查更新

控制页提供“检查更新”。APP 会访问公开的 GitHub Releases API，检查 `BH2VSQ/QSL_manager_mobile` 的最新正式 Release；GitHub 的 latest release 接口只返回已发布且非草稿、非预发布版本。

Release 中上传 `.apk` 资产后，APP 会显示版本号与 Release Notes，用户可选择下载 APK；下载完成后可选择立即安装。Android 8.0 及以上系统会要求用户允许 QSLMM 安装来自其他来源的应用，这是 Android Package Installer 的系统安全机制。

GitHub Release 标签建议使用 `v0.2.11` 这样的语义化版本，并在 Release Assets 中上传可直接安装的通用 APK。



## 自动构建与发布

GitHub Actions 工作流位于 `.github/workflows/release.yml`。向 `main` 分支 push 后会自动执行依赖安装、静态检查、测试、正式签名 APK 构建，并创建 GitHub Release，同时上传 APK 和 SHA-256 校验文件。

首次启用前需要在 GitHub `Settings -> Secrets and variables -> Actions` 中配置：

```text
ANDROID_KEYSTORE_BASE64
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
```

具体配置方法见 `docs/GITHUB_ACTIONS_RELEASE.md`。


### 依赖兼容说明

`file_picker 13.x` 使用 `win32 6.x`，因此项目使用 `package_info_plus 10.2.2` 以避免与 Windows 平台依赖产生版本冲突。`package_info_plus 10.2.2` 要求 Flutter >=3.38.1、Java 17、AGP >=8.12.1；本项目已同步 Android 构建工具链。
