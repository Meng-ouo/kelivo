import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 单个 BLE 设备配置。
///
/// 所有字段用户自填——不写死任何 UUID 或协议值。
/// 这是通用 BLE 连接配置，适配任何符合标准 GATT 协议的设备。
class BleDeviceConfig {
  final String id;
  final String name; // 用户起的名字，方便识别
  final String serviceUuid; // 服务 UUID
  final String writeUuid; // 写特征 UUID
  final String? notifyUuid; // 通知特征 UUID（可选）
  final String writeMethod; // 'withResponse' 或 'withoutResponse'
  final int reconnectInterval; // 断线重连间隔（秒）
  final int retryCount; // 单条指令重发次数
  final int connectTimeout; // 连接超时（秒）
  final int keepAliveInterval; // 保活重发间隔（毫秒，0=不保活）
  final String stopData; // 停止指令 hex（用户自填，空=不发包直接停保活）

  BleDeviceConfig({
    required this.id,
    required this.name,
    required this.serviceUuid,
    required this.writeUuid,
    this.notifyUuid,
    this.writeMethod = 'withoutResponse',
    this.reconnectInterval = 3,
    this.retryCount = 3,
    this.connectTimeout = 10,
    this.keepAliveInterval = 0,
    this.stopData = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'serviceUuid': serviceUuid,
        'writeUuid': writeUuid,
        'notifyUuid': notifyUuid,
        'writeMethod': writeMethod,
        'reconnectInterval': reconnectInterval,
        'retryCount': retryCount,
        'connectTimeout': connectTimeout,
        'keepAliveInterval': keepAliveInterval,
        'stopData': stopData,
      };

  factory BleDeviceConfig.fromJson(Map<String, dynamic> json) {
    return BleDeviceConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      serviceUuid: json['serviceUuid'] as String,
      writeUuid: json['writeUuid'] as String,
      notifyUuid: json['notifyUuid'] as String?,
      writeMethod: json['writeMethod'] as String? ?? 'withoutResponse',
      reconnectInterval: json['reconnectInterval'] as int? ?? 3,
      retryCount: json['retryCount'] as int? ?? 3,
      connectTimeout: json['connectTimeout'] as int? ?? 10,
      keepAliveInterval: json['keepAliveInterval'] as int? ?? 0,
      stopData: json['stopData'] as String? ?? '',
    );
  }

  BleDeviceConfig copyWith({
    String? name,
    String? serviceUuid,
    String? writeUuid,
    String? notifyUuid,
    String? writeMethod,
    int? reconnectInterval,
    int? retryCount,
    int? connectTimeout,
    int? keepAliveInterval,
    String? stopData,
  }) {
    return BleDeviceConfig(
      id: id,
      name: name ?? this.name,
      serviceUuid: serviceUuid ?? this.serviceUuid,
      writeUuid: writeUuid ?? this.writeUuid,
      notifyUuid: notifyUuid ?? this.notifyUuid,
      writeMethod: writeMethod ?? this.writeMethod,
      reconnectInterval: reconnectInterval ?? this.reconnectInterval,
      retryCount: retryCount ?? this.retryCount,
      connectTimeout: connectTimeout ?? this.connectTimeout,
      keepAliveInterval: keepAliveInterval ?? this.keepAliveInterval,
      stopData: stopData ?? this.stopData,
    );
  }
}

/// BLE 设备配置存储。
///
/// 管理多套用户保存的 BLE 设备配置：
/// - 增删改查
/// - 切换当前选中的配置
/// - 序列化到 SharedPreferences
class BleConfigStore extends ChangeNotifier {
  static const String _storageKey = 'ble_device_configs';
  static const String _activeKey = 'ble_config_active';

  final List<BleDeviceConfig> _configs = [];
  String? _activeId;

  List<BleDeviceConfig> get configs => List.unmodifiable(_configs);
  String? get activeId => _activeId;

  BleDeviceConfig? get activeConfig {
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
            .addAll(list.map((e) => BleDeviceConfig.fromJson(e as Map<String, dynamic>)));
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
  Future<BleDeviceConfig> add({
    required String name,
    String serviceUuid = '',
    String writeUuid = '',
    String? notifyUuid,
    String writeMethod = 'withoutResponse',
    int reconnectInterval = 3,
    int retryCount = 3,
    int connectTimeout = 10,
    int keepAliveInterval = 0,
    String stopData = '',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final config = BleDeviceConfig(
      id: 'ble_$now',
      name: name,
      serviceUuid: serviceUuid,
      writeUuid: writeUuid,
      notifyUuid: notifyUuid,
      writeMethod: writeMethod,
      reconnectInterval: reconnectInterval,
      retryCount: retryCount,
      connectTimeout: connectTimeout,
      keepAliveInterval: keepAliveInterval,
      stopData: stopData,
    );
    _configs.add(config);
    await _persist();
    notifyListeners();
    return config;
  }

  /// 更新配置
  Future<void> update(BleDeviceConfig config) async {
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
