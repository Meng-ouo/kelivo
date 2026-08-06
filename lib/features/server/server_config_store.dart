import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 单个服务器配置。
///
/// 所有字段用户自填——不写死任何地址或 token。
/// 这是通用的服务器联动配置，适配任何兼容 OpenAI 风格或自定义端点的服务。
class ServerConfig {
  final String id;
  final String name; // 用户起的名字
  final String baseUrl; // 服务器基础 URL
  final String token; // 认证 token
  final String? chatEndpoint; // 便笺/聊天端点路径（可选，相对 baseUrl）
  final String? pushEndpoint; // 指令推送端点路径（可选）
  final String? statusEndpoint; // 状态查询端点路径（可选）
  final bool enabled; // 是否启用

  ServerConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.token = '',
    this.chatEndpoint,
    this.pushEndpoint,
    this.statusEndpoint,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'token': token,
        'chatEndpoint': chatEndpoint,
        'pushEndpoint': pushEndpoint,
        'statusEndpoint': statusEndpoint,
        'enabled': enabled,
      };

  factory ServerConfig.fromJson(Map<String, dynamic> json) {
    return ServerConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      baseUrl: json['baseUrl'] as String,
      token: json['token'] as String? ?? '',
      chatEndpoint: json['chatEndpoint'] as String?,
      pushEndpoint: json['pushEndpoint'] as String?,
      statusEndpoint: json['statusEndpoint'] as String?,
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  ServerConfig copyWith({
    String? name,
    String? baseUrl,
    String? token,
    String? chatEndpoint,
    String? pushEndpoint,
    String? statusEndpoint,
    bool? enabled,
  }) {
    return ServerConfig(
      id: id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      token: token ?? this.token,
      chatEndpoint: chatEndpoint ?? this.chatEndpoint,
      pushEndpoint: pushEndpoint ?? this.pushEndpoint,
      statusEndpoint: statusEndpoint ?? this.statusEndpoint,
      enabled: enabled ?? this.enabled,
    );
  }
}

/// 服务器配置存储。
///
/// 管理多套用户保存的服务器配置：
/// - 增删改查
/// - 切换当前选中的配置
/// - 序列化到 SharedPreferences
class ServerConfigStore extends ChangeNotifier {
  static const String _storageKey = 'server_configs';
  static const String _activeKey = 'server_config_active';

  final List<ServerConfig> _configs = [];
  String? _activeId;

  List<ServerConfig> get configs => List.unmodifiable(_configs);
  String? get activeId => _activeId;

  ServerConfig? get activeConfig {
    if (_activeId == null) return null;
    try {
      return _configs.firstWhere((c) => c.id == _activeId);
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
        _configs.clear();
        _configs
            .addAll(list.map((e) => ServerConfig.fromJson(e as Map<String, dynamic>)));
      } catch (_) {}
    }
    _activeId = prefs.getString(_activeKey);
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_configs.map((c) => c.toJson()).toList());
    await prefs.setString(_storageKey, json);
  }

  /// 新增配置
  Future<ServerConfig> add({
    required String name,
    String baseUrl = '',
    String token = '',
    String? chatEndpoint,
    String? pushEndpoint,
    String? statusEndpoint,
    bool enabled = true,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final config = ServerConfig(
      id: 'srv_$now',
      name: name,
      baseUrl: baseUrl,
      token: token,
      chatEndpoint: chatEndpoint,
      pushEndpoint: pushEndpoint,
      statusEndpoint: statusEndpoint,
      enabled: enabled,
    );
    _configs.add(config);
    await _persist();
    notifyListeners();
    return config;
  }

  /// 更新配置
  Future<void> update(ServerConfig config) async {
    final idx = _configs.indexWhere((c) => c.id == config.id);
    if (idx >= 0) {
      _configs[idx] = config;
      await _persist();
      notifyListeners();
    }
  }

  /// 删除配置
  Future<void> delete(String id) async {
    _configs.removeWhere((c) => c.id == id);
    if (_activeId == id) {
      _activeId = _configs.isNotEmpty ? _configs.first.id : null;
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

  /// 设为当前选中的配置
  Future<void> setActive(String id) async {
    _activeId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey, id);
    notifyListeners();
  }
}
