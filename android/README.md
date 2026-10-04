# Android 工程说明

本目录已包含可直接用于 Flutter Android 构建的工程配置。

- 应用显示名称：QSLMM
- Android Application ID：cn.bh2vsq.qslmanager
- Launcher Icon：`app/src/main/res/mipmap-*/ic_launcher.png`
- 图标源：项目根目录 `assets/icon/qslmm_icon.png`
- Flutter 3.41 兼容工具链：AGP 8.12.1 / Gradle 8.14 / Kotlin 2.2.20

如需更换图标，替换 `assets/icon/qslmm_icon.png` 后同步更新 `app/src/main/res/mipmap-*` 下的 `ic_launcher.png` 与 `ic_launcher_round.png`。


### 依赖兼容说明

`file_picker 13.x` 使用 `win32 6.x`，因此项目使用 `package_info_plus 10.2.2` 以避免与 Windows 平台依赖产生版本冲突。`package_info_plus 10.2.2` 要求 Flutter >=3.38.1、Java 17、AGP >=8.12.1；本项目已同步 Android 构建工具链。
