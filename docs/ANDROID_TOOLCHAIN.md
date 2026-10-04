# Android 工具链说明

本版本针对 Flutter 3.44+ 使用 AGP 9 过渡配置：

- Gradle 9.3.1
- Android Gradle Plugin 9.1.1
- Kotlin Gradle Plugin 2.3.20
- `android.builtInKotlin=false`（按 Flutter AGP 9 过渡期兼容路径）
- Java/JDK 17

Flutter 官方说明：AGP 9+ 必须迁移到 Built-in Kotlin 才能启用 `android.builtInKotlin=true`；Flutter 3.44 提供 AGP 9 的过渡支持，Flutter 3.47 才支持启用 Built-in Kotlin。
