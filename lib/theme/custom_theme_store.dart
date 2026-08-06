import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'custom_theme.dart';

/// 自定义主题存储。
///
/// 管理多套用户保存的自定义主题：
/// - 增删改查
/// - 试穿（预览但未确认）
/// - 落库（确认保存）
/// - 序列化到 SharedPreferences
///
/// 抄 Polaris 的分层思路：
/// - 试穿 = 改了能看效果但没确认
/// - 落库 = 确认了写入持久存储
class CustomThemeStore extends ChangeNotifier {
  static const String _storageKey = 'custom_themes';
  static const String _activeKey = 'custom_theme_active';

  final List<CustomTheme> _themes = [];
  CustomTheme? _tryingOn; // 试穿中的主题（未确认）
  String? _activeId; // 当前激活的自定义主题 ID

  List<CustomTheme> get themes => List.unmodifiable(_themes);
  CustomTheme? get tryingOn => _tryingOn;
  String? get activeId => _activeId;
  bool get isTrying => _tryingOn != null;

  /// 试穿中的主题（如果有），否则返回激活的主题
  CustomTheme? get currentTheme => _tryingOn ?? _getActive();

  CustomTheme? _getActive() {
    if (_activeId == null) return null;
    try {
      return _themes.firstWhere((t) => t.id == _activeId);
    } catch (_) {
      return null;
    }
  }

  /// 从 SharedPreferences 加载
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _themes.clear();
        _themes.addAll(list.map((e) =>
            CustomTheme.fromJson(e as Map<String, dynamic>)));
      } catch (_) {}
    }
    _activeId = prefs.getString(_activeKey);
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_themes.map((t) => t.toJson()).toList());
    await prefs.setString(_storageKey, json);
  }

  /// 新建主题（进入试穿状态）
  CustomTheme createTheme({
    String name = '新主题',
    CustomColorScheme? light,
    CustomColorScheme? dark,
  }) {
    final theme = CustomTheme.create(
      name: name,
      light: light,
      dark: dark,
    );
    _tryingOn = theme;
    notifyListeners();
    return theme;
  }

  /// 从现有 ColorScheme 克隆一个新主题（试穿）
  CustomTheme cloneFrom(String name, ColorScheme light, ColorScheme dark) {
    final theme = CustomTheme.create(
      name: name,
      light: CustomColorScheme.fromColorScheme(light),
      dark: CustomColorScheme.fromColorScheme(dark),
    );
    _tryingOn = theme;
    notifyListeners();
    return theme;
  }

  /// 试穿一个已保存的主题（预览但不切换）
  void tryOn(CustomTheme theme) {
    _tryingOn = theme;
    notifyListeners();
  }

  /// 试穿时修改颜色（实时预览）
  void updateTryingColor({
    required bool isLight,
    required String key,
    required int value,
  }) {
    if (_tryingOn == null) return;
    final cs = isLight ? _tryingOn!.light : _tryingOn!.dark;
    final newCs = cs.copyWithColor(key, value);
    _tryingOn = _tryingOn!.copyWith(
      light: isLight ? newCs : null,
      dark: isLight ? null : newCs,
    );
    notifyListeners();
  }

  /// 试穿时改名字
  void updateTryingName(String name) {
    if (_tryingOn == null) return;
    _tryingOn = _tryingOn!.copyWith(name: name);
    notifyListeners();
  }

  /// 落库：确认试穿的主题，保存到列表并设为激活
  Future<void> commit() async {
    if (_tryingOn == null) return;
    final idx = _themes.indexWhere((t) => t.id == _tryingOn!.id);
    if (idx >= 0) {
      _themes[idx] = _tryingOn!;
    } else {
      _themes.add(_tryingOn!);
    }
    _activeId = _tryingOn!.id;
    _tryingOn = null;
    await _persist();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey, _activeId!);
    notifyListeners();
  }

  /// 取消试穿（丢弃未确认的改动）
  void cancelTryOn() {
    _tryingOn = null;
    notifyListeners();
  }

  /// 直接应用一个已保存的主题
  Future<void> apply(String id) async {
    _activeId = id;
    _tryingOn = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey, id);
    notifyListeners();
  }

  /// 删除主题
  Future<void> delete(String id) async {
    _themes.removeWhere((t) => t.id == id);
    if (_activeId == id) {
      _activeId = _themes.isNotEmpty ? _themes.first.id : null;
      final prefs = await SharedPreferences.getInstance();
      if (_activeId != null) {
        await prefs.setString(_activeKey, _activeId!);
      } else {
        await prefs.remove(_activeKey);
      }
    }
    await _persist();
    notifyListeners();
  }

  /// 编辑一个已保存的主题（进入试穿）
  void edit(CustomTheme theme) {
    _tryingOn = theme;
    notifyListeners();
  }

  /// 清除激活的自定义主题（回到内置色板）
  Future<void> clearActive() async {
    _activeId = null;
    _tryingOn = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeKey);
    notifyListeners();
  }

  String exportTheme(String id) {
    final t = _themes.firstWhere((t) => t.id == id);
    return t.toJsonString();
  }

  /// 从 JSON 字符串导入主题
  Future<CustomTheme> importTheme(String jsonStr) async {
    final theme = CustomTheme.fromJsonString(jsonStr);
    _themes.add(theme);
    await _persist();
    notifyListeners();
    return theme;
  }
}
