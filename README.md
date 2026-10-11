# DoneList

DoNow 是一个 macOS 14+ 原生悬浮计时工具。点击桌面悬浮球选择预设事项，倒计时完成后保存完成记录，并尝试写入系统日历。

## 当前实现

- 可拖动、跨 Space 显示并记忆位置的悬浮球
- 事项的新增、编辑、归档和本地持久化
- 单活动计时器，支持暂停、继续、放弃
- 睡眠唤醒和重启后的活动会话恢复/补结算
- 本地到期通知
- EventKit 仅写权限和完成事件创建
- 完成历史与日历同步状态
- 用户可控的开机启动设置

## 开发运行

1. 使用 Xcode 16 或更新版本打开 `DoNow.xcodeproj`（不要运行 `Package.swift` 的可执行产物）。
2. 选择 `DoNow` scheme 和 `My Mac`。
3. Run。

命令行测试：

```sh
swift test
```

## 签名和权限

`DoNow.xcodeproj` 已包含正式 macOS App target，并配置：

- Bundle identifier
- Development Team 和签名
- App Sandbox
- Calendar entitlement：`com.apple.security.personal-information.calendars`
- `NSCalendarsWriteOnlyAccessUsageDescription`

相关配置位于 `Config/Info.plist` 和 `Config/DoNow.entitlements`。`Package.swift` 保留用于命令行单元测试；直接运行 Swift Package 可执行产物时，通知功能会自动关闭。

完整架构与后续阶段见 [ARCHITECTURE_PLAN.md](ARCHITECTURE_PLAN.md)。
