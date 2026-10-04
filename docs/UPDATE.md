# QSLMM 应用更新

## 检查版本

控制页的“检查更新”会访问公开的 GitHub Releases API：

`https://api.github.com/repos/BH2VSQ/QSL_manager_mobile/releases/latest`

GitHub 官方文档说明，`Get the latest release` 返回最新的已发布、非 draft、非 prerelease Release；公开仓库可以不带认证调用。

## 发布新版本

从现在起，GitHub Actions 会在 `main` 分支每次 push 后自动构建并发布 Release。Release 标签使用 `v<versionName>+<buildNumber>`，其中 `buildNumber` 为 `pubspec.yaml` 中现有 build number 加 GitHub Actions 运行编号。

APP 会自动选择 Release 中的 APK 文件，优先选择文件名包含 `qslmm` 的 APK。

## 下载与安装

用户在 APP 中选择“下载更新”后，APK 会下载到 QSLMM 的临时目录。下载完成后用户可以选择“安装更新”。Android 8.0（API 26）及以上要求应用获得“允许安装未知应用”的授权；APP 会在未授权时打开对应的系统设置。Android 官方 `PackageManager.canRequestPackageInstalls()` 文档说明，应用需要声明 `REQUEST_INSTALL_PACKAGES` 并由用户明确允许安装来自其他来源的软件包。

## 签名要求

更新 APK 必须保持相同的 Android Application ID：

`cn.bh2vsq.qslmanager`

并继续使用相同的签名密钥，否则 Android 无法将其作为当前 QSLMM 的升级包安装。

## 修改仓库

如果未来移动端源码仓库名称不是 `BH2VSQ/QSL_manager_mobile`，只需修改：

`lib/services/github_update_service.dart`

中的：

```dart
static const githubOwner = 'BH2VSQ';
static const githubRepo = 'QSL_manager_mobile';
```
