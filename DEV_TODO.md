# 小书房 TODO

> 每次开干前看一遍。改了什么、还差什么、哪个联动哪个。

## 当前状态
- fork 地址：我的 GitHub 号/kelivo，分支 master
- CI workflow：build.yml（id=328299280），workflow_dispatch 只选 build_ios
- 已通过 CI 的 commit：10c39b63（主题修复）、67116718（BLE config + server config）
- 当前 CI：0b92fbb3（BLE manager + flutter_blue_plus 原生依赖）

## 四个必须功能（醒醒定的）
1. [~] 蓝牙稳定 — BLE manager 写好了，CI 验证中（flutter_blue_plus 原生依赖）
2. [x] 服务器配置页 — store + page + settings 入口已完成，CI 通过
3. [ ] GitHub MCP — Kelivo 自带 MCP 支持，加 GitHub MCP server 配置（还没开始）
4. [x] 主题系统 — CustomTheme 模型 + 存储 + 编辑器 + 入口，CI 通过

## 主题系统进度（CI 已通过）
- [x] `lib/theme/custom_theme.dart` — CustomTheme 模型 + CustomColorScheme
- [x] `lib/theme/custom_theme_store.dart` — 主题存储（增删改查/试穿/落库/导入导出/clearActive）
- [x] `lib/features/settings/pages/custom_theme_editor_page.dart` — 主题编辑器（HSV 滑杆 + 实时预览 + 试穿/确认）
- [x] `lib/theme/palettes.dart` — 加了奶霜莓粉色板 cream_berry
- [x] `lib/core/providers/settings_provider.dart` — 默认色板改成 cream_berry
- [x] `lib/main.dart` — 加 import + CustomThemeStore Provider + 主题构建逻辑加自定义主题分支
- [x] `lib/features/settings/pages/theme_settings_page.dart` — 加自定义主题入口
- [x] **修复 CustomTheme.create 缺 createdAt/updatedAt 参数**（10c39b63）

## BLE 模块进度
- [x] `lib/features/ble/ble_config_store.dart` — 设备配置存储（增删改查/setActive，SharedPreferences）
- [x] `lib/features/ble/ble_manager.dart` — 通用 BLE 管理器（扫描/连接/发现服务/写指令带重发/订阅通知/断线重连）
- [x] `lib/features/settings/pages/ble_config_page.dart` — 配置列表 + 编辑页
- [x] `lib/main.dart` — 加 BleConfigStore + BleManager Provider
- [x] `lib/features/settings/pages/settings_page.dart` — 加 BLE 设备入口
- [x] `lib/icons/lucide_adapter.dart` — 加 Bluetooth + Server 图标
- [x] `pubspec.yaml` — 加 flutter_blue_plus ^2.3.11
- [x] `ios/Runner/Info.plist` — 加 NSBluetoothAlwaysUsageDescription
- [~] **CI 验证中** — flutter_blue_plus 原生依赖能否在 macOS runner pod install 成功

## 服务器配置进度（CI 已通过）
- [x] `lib/features/server/server_config_store.dart` — 服务器配置存储（URL/token/端点，用户自填）
- [x] `lib/features/settings/pages/server_config_page.dart` — 配置列表 + 编辑页
- [x] `lib/main.dart` — 加 ServerConfigStore Provider
- [x] `lib/features/settings/pages/settings_page.dart` — 加服务器入口

## 其他还没做
- [ ] GitHub MCP（Kelivo 自带 MCP 配置，加一个 GitHub MCP server）
- [ ] 无声音乐保活（iOS 原生 Info.plist + AVAudioSession）
- [ ] 思维链查看（Kelivo bug #834 修复）
- [ ] ble_config_page 加连接按钮（调用 BleManager.connect/disconnect/sendCommand）
- [ ] GitHubService（照小手机 github-tool.js 思路，Dart 版）

## 核心原则（醒醒定的）
- 对外代码完全中性、隐私安全
- 蓝牙模块叫通用名（BLE 设备连接），UUID/协议格式用户自填不写死
- 服务器配置是用户自填功能（URL/token/端点在设置页填），代码里不写死任何地址
- GitHub fork 公开，看不出连什么设备、连什么服务器

## 开发循环
iSH 写 Dart → git push → GitHub Actions macOS runner 编译 → 看报错 → 改 → 再 push
触发 CI：API POST /repos/{owner}/kelivo/actions/workflows/328299280/dispatches，inputs build_ios=true
查 CI 状态：API GET /repos/{owner}/kelivo/actions/runs?per_page=3
下载 ipa：GitHub Actions 页面 artifact iOS-IPA → 全能签装机
