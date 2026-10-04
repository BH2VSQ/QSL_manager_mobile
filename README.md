# QSL Manager Mobile

基于 Flutter 开发的 Android 移动端控制台，用于连接 [BH2VSQ/QSLCard-Manager](https://github.com/BH2VSQ/QSLCard-Manager) 的 REST API。

> 当前项目主要面向 Android 手机使用。APP 不实现业务数据库，数据与 QSL 业务流程均由 QSLCard-Manager 服务器处理。

## 界面

采用专业控制台风格，核心配色：

- 蓝色：`#5BCFFA`
- 粉色：`#F5ABB9`
- 白色：`#FFFFFF`

支持**白天 / 夜间模式**切换，并记忆用户选择。

## 功能

### 概览

- API 在线状态
- QSO 总数
- 已发 QSL
- 已收 QSL
- 待处理数量
- 最近收发卡活动

### QSO 日志

- 分页查看日志
- 呼号搜索
- 查看完整日志详情
- 编辑日志
- ADIF 文件上传
- 单条或多条日志选择
- 按选择的日志颁发 TC / RC QSL 编号
- 支持单卡合并或逐条发号
- 每条日志显示收卡 / 发卡状态

QSL 颁号完成后，打印任务仍由服务器加入打印队列；手机端不显示打印队列。

### QSL 卡片

- 按 QSL 编号搜索
- 扫码输入 QSL 编号
- 查看卡片详情
- 查看关联日志
- QSL 标签补打

### 扫码

- 扫描 QSL 二维码
- 扫描结果提交服务器的收发卡流程
- 相机生命周期在标签页切换和 APP 前后台切换时自动管理

### 地址簿

- 新建 / 编辑 / 删除地址
- 地址、邮政编码、电话、国家 / 地区独立保存
- 国家 / 地区字段可留空
- 地址标签打印支持：
  - `FROM（发自）`
  - `TO（发往）`
- 打印任务直接推送至服务器打印队列，手机端不显示队列

### 设置

- 修改 QSL Manager API 服务器地址
- 测试服务器连接
- 白天 / 夜间模式

## API 服务器

默认 API：

```text
http://10.0.2.2:7055/api
```

`10.0.2.2` 仅适用于 Android Emulator，真机应填写 QSL Manager 服务器在局域网中的地址，例如：

```text
http://192.168.x.xxx:7055/api
```

也可以直接输入：

```text
192.168.x.xxx:7055
```

APP 会自动补齐 `http://` 和 `/api`。

健康检查接口：

```text
GET /api/health
```

## 开发环境

推荐使用当前稳定版 Flutter SDK，并确保 Dart SDK 满足 `pubspec.yaml` 中的最低版本要求。

安装依赖：

```powershell
flutter pub get
```

运行：

```powershell
flutter run
```

构建 Release APK：

```powershell
flutter clean
flutter pub get
flutter build apk --release
```

输出通常位于：

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Android 初始化

当前仓库提交的是 Flutter/Dart 应用源码；首次准备 Android 平台文件时执行：

```powershell
flutter create . --platforms=android
flutter pub get
```

项目使用 HTTP API 时，需要确认 AndroidManifest 允许 cleartext HTTP，并声明网络与摄像头权限。可以参考：

```text
docs/ANDROID_SETUP.md
```

如果你已经有可正常构建的 `android/` 目录，建议直接将该目录一并提交到 GitHub，而不必重复执行 `flutter create`。

## API 对照

移动端主要使用的接口见：

```text
docs/API_MAPPING.md
```

API 的正式定义以 QSLCard-Manager 仓库中的 `docs/API.md` 为准。

## 项目结构

```text
qsl_manager_mobile/
├── lib/
│   ├── core/          # 全局控制器、主题
│   ├── models/        # 数据模型
│   ├── screens/       # 页面
│   ├── services/      # REST API
│   ├── widgets/       # 通用控制台组件
│   └── main.dart      # 程序入口
├── docs/
│   ├── API_MAPPING.md
│   └── ANDROID_SETUP.md
├── analysis_options.yaml
├── pubspec.yaml
└── README.md
```

## GitHub 发布建议

不要提交以下内容：

- `.dart_tool/`
- `build/`
- IDE 配置文件
- APK / AAB
- 本地服务器配置
- Android 签名密钥

项目已经提供 `.gitignore` 处理常见情况。

## 版本

当前移动端版本：**0.2.5**
