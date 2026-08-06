# 小书房 TODO

> 每次开干前看一遍。改了什么、还差什么、哪个联动哪个。

## 当前状态
- CI 编译中（第一波：加色板 + 改默认色板），等结果
- fork 地址：我的 GitHub 号/kelivo，分支 master
- CI workflow：build.yml（id=328299280），workflow_dispatch 只选 build_ios

## 四个必须功能（醒醒定的）
1. [x] 蓝牙稳定 — 现有协议翻译成 Dart（还没开始写）
2. [ ] 服务器配置页 — 设置页填 URL/token/端点（还没开始）
3. [ ] GitHub MCP — Kelivo 自带 MCP 支持，加 GitHub MCP server 配置（还没开始）
4. [~] 主题系统 — 抄 Polaris 分层+试穿思路（写了模型+存储+编辑器，还没接入主程序）

## 主题系统进度
- [x] `lib/theme/custom_theme.dart` — CustomTheme 模型 + CustomColorScheme（序列化/反序列化/toColorScheme）
- [x] `lib/theme/custom_theme_store.dart` — 主题存储（增删改查/试穿/落库/导入导出）
- [x] `lib/features/settings/pages/custom_theme_editor_page.dart` — 主题编辑器页面（HSV 颜色选择器 + 实时预览 + 试穿/确认）
- [x] `lib/theme/palettes.dart` — 加了奶霜莓粉色板 cream_berry
- [x] `lib/core/providers/settings_provider.dart` — 默认色板改成 cream_berry
- [ ] **联动：SettingsProvider 加 setCustomTheme 方法**（让主题编辑器能应用自定义主题到全局）
- [ ] **联动：theme_factory.dart 加 buildThemeFromCustom 方法**（从 CustomTheme 构建 ThemeData）
- [ ] **联动：theme_settings_page.dart 加入"自定义主题"入口**（跳转到编辑器页面）
- [ ] **联动：main.dart 或 app.dart 注册 CustomThemeStore 到 Provider**（让编辑器能 context.read）
- [ ] **联动：app.dart 的 ThemeData 构建逻辑加自定义主题分支**（当前用的是 paletteId 走 ThemePalettes，需要加 custom 分支）

## 其他还没做
- [ ] BLE 模块（pubspec.yaml 加 flutter_blue_plus + lib/features/ble/ 目录）
- [ ] 服务器配置页（lib/features/settings/pages/server_config_page.dart）
- [ ] GitHub MCP（Kelivo 自带 MCP 配置，加一个 GitHub MCP server）
- [ ] 无声音乐保活（iOS 原生 Info.plist + AVAudioSession）
- [ ] 思维链查看（Kelivo bug #834 修复）

## 开发循环
iSH 写 Dart → git push → GitHub Actions macOS runner 编译 → 看报错 → 改 → 再 push
触发 CI：API POST /repos/{owner}/kelivo/actions/workflows/328299280/dispatches，inputs build_ios=true
查 CI 状态：API GET /repos/{owner}/kelivo/actions/runs?per_page=3
下载 ipa：GitHub Actions 页面 artifact iOS-IPA → 全能签装机
