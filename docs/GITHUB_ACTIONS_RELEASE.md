# GitHub Actions 自动构建与发布

仓库：`BH2VSQ/QSL_manager_mobile`

工作流文件：`.github/workflows/release.yml`

## 触发方式

向 `main` 分支 push（每次 commit 被 push 到 main）会自动执行：

1. 安装 Flutter 3.41.0 与 Java 17。
2. 读取 `pubspec.yaml` 的版本名。
3. 使用 GitHub Actions 的运行编号生成唯一 `versionCode`。
4. 使用 GitHub Secrets 中的正式 keystore 签名 APK。
5. 执行 `flutter analyze` 与 `flutter test`。
6. 构建 Release APK。
7. 计算 SHA-256。
8. 自动创建 GitHub Release 并上传 APK。

也可以在 GitHub Actions 页面手动执行 `workflow_dispatch`。

## Release 版本规则

例如 `pubspec.yaml` 当前为：

```yaml
version: 0.2.10+19
```

第一次 GitHub Actions 运行编号为 `1` 时，CI 会构建：

```text
versionName = 0.2.10
versionCode = 20
Release tag = v0.2.10+20
APK = QSLMM-v0.2.10+20.apk
```

这样即使连续 commit 而没有手动修改 `pubspec.yaml`，每个 Release 仍然具有唯一且递增的 Android build number。

当你需要正式提升版本时，只修改 `pubspec.yaml` 的 versionName，例如：

```yaml
version: 0.2.11+1
```

后续构建会继续在此基础上递增 CI build number。

## 配置签名 Secrets

在 GitHub 仓库：

`Settings -> Secrets and variables -> Actions -> New repository secret`

建立以下四个 Secrets：

```text
ANDROID_KEYSTORE_BASE64
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
```

其中 `ANDROID_KEYSTORE_BASE64` 是正式 `.jks` 文件的 Base64 内容。Windows PowerShell 可以使用：

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\path\qslmm-release.jks")) | Set-Clipboard
```

然后将剪贴板中的内容粘贴到 GitHub Secret。

不要把 `key.properties`、`.jks` 或密码提交到仓库。

## APP 自动检查更新

QSLMM 的移动端更新服务已经使用正式仓库：

```text
BH2VSQ/QSL_manager_mobile
```

并同时比较 `versionName` 与 `buildNumber`。因此同一个 `versionName` 下的新 CI 构建也能够被 APP 识别为更新。
