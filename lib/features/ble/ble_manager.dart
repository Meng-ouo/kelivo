import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_config_store.dart';

/// BLE 连接状态。
enum BleConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  reconnecting,
  error,
}

/// 通用 BLE 管理器。
///
/// 功能：
/// - 按配置的服务 UUID 扫描并连接设备
/// - 发现写特征 / 通知特征
/// - 发送指令（带重发）
/// - 订阅通知数据
/// - 断线自动重连
///
/// 所有 UUID / 协议参数来自用户配置，不写死任何值。
class BleManager extends ChangeNotifier {
  BleConnectionState _state = BleConnectionState.disconnected;
  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeChar;
  BluetoothCharacteristic? _notifyChar;
  BleDeviceConfig? _config;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _notifySub;
  Timer? _reconnectTimer;
  Timer? _scanTimeout;
  String? _error;

  /// 当前状态
  BleConnectionState get state => _state;
  bool get isConnected => _state == BleConnectionState.connected;
  String? get error => _error;
  BleDeviceConfig? get config => _config;
  BluetoothDevice? get device => _device;

  void _setState(BleConnectionState s) {
    _state = s;
    notifyListeners();
  }

  void _setError(String msg) {
    _error = msg;
    _setState(BleConnectionState.error);
  }

  /// 扫描并连接设备。
  Future<void> connect(BleDeviceConfig config) async {
    _config = config;
    _error = null;
    _cleanup();
    _setState(BleConnectionState.scanning);

    final serviceGuid = Guid(config.serviceUuid);
    _scanSub = FlutterBluePlus.scanResults.listen((results) async {
      if (results.isNotEmpty && _state == BleConnectionState.scanning) {
        await FlutterBluePlus.stopScan();
        _scanTimeout?.cancel();
        await _connectToDevice(results.first.device);
      }
    });

    try {
      await FlutterBluePlus.startScan(withServices: [serviceGuid]);
    } catch (e) {
      _setError('扫描失败: $e');
      return;
    }

    // 扫描超时
    _scanTimeout = Timer(
      Duration(seconds: config.connectTimeout),
      () {
        if (_state == BleConnectionState.scanning) {
          FlutterBluePlus.stopScan();
          _setError('扫描超时，未发现设备');
        }
      },
    );
  }

  Future<void> _connectToDevice(BluetoothDevice dev) async {
    _device = dev;
    _setState(BleConnectionState.connecting);

    // 监听连接状态
    _connSub = dev.connectionState.listen((cs) {
      if (cs == BluetoothConnectionState.connected) {
        if (_state != BleConnectionState.connected) {
          _setState(BleConnectionState.connected);
          _discoverAndSetup();
        }
      } else if (cs == BluetoothConnectionState.disconnected) {
        if (_state != BleConnectionState.disconnected) {
          _setState(BleConnectionState.reconnecting);
          _startReconnect();
        }
      }
    });

    try {
      await dev.connect(timeout: Duration(seconds: _config!.connectTimeout));
    } catch (e) {
      _setError('连接失败: $e');
    }
  }

  /// 发现服务并设置写特征 / 通知特征
  Future<void> _discoverAndSetup() async {
    if (_device == null || _config == null) return;
    try {
      final services = await _device!.discoverServices();
      final serviceGuid = Guid(_config!.serviceUuid);
      for (final svc in services) {
        if (svc.uuid == serviceGuid) {
          // 写特征
          if (_config!.writeUuid.isNotEmpty) {
            final writeGuid = Guid(_config!.writeUuid);
            for (final c in svc.characteristics) {
              if (c.uuid == writeGuid) {
                _writeChar = c;
                break;
              }
            }
          }
          // 通知特征
          if (_config!.notifyUuid != null &&
              _config!.notifyUuid!.isNotEmpty) {
            final notifyGuid = Guid(_config!.notifyUuid!);
            for (final c in svc.characteristics) {
              if (c.uuid == notifyGuid) {
                _notifyChar = c;
                await c.setNotifyValue(true);
                _notifySub = c.lastValueStream.listen((data) {
                  // 通知数据流，子类可 override 处理
                });
                break;
              }
            }
          }
          break;
        }
      }
      notifyListeners();
    } catch (e) {
      _setError('发现服务失败: $e');
    }
  }

  /// 发送指令（带重发）。
  /// 返回是否至少成功一次。
  Future<bool> sendCommand(List<int> data) async {
    if (!isConnected || _writeChar == null) return false;
    final withoutResponse = _config?.writeMethod == 'withoutResponse';
    for (int i = 0; i < (_config?.retryCount ?? 3); i++) {
      try {
        await _writeChar!.write(data, withoutResponse: withoutResponse);
        return true;
      } catch (e) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    return false;
  }

  /// 断线重连
  void _startReconnect() {
    _reconnectTimer?.cancel();
    final interval = _config?.reconnectInterval ?? 3;
    _reconnectTimer = Timer.periodic(
      Duration(seconds: interval),
      (_) async {
        if (_device != null && _config != null) {
          try {
            await _device!
                .connect(timeout: Duration(seconds: _config!.connectTimeout));
            _reconnectTimer?.cancel();
          } catch (_) {
            // 继续重试
          }
        }
      },
    );
  }

  /// 主动断开
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    if (_device != null) {
      try {
        await _device!.disconnect();
      } catch (_) {}
    }
    _cleanup();
    _setState(BleConnectionState.disconnected);
  }

  void _cleanup() {
    _scanSub?.cancel();
    _scanSub = null;
    _connSub?.cancel();
    _connSub = null;
    _notifySub?.cancel();
    _notifySub = null;
    _scanTimeout?.cancel();
    _scanTimeout = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _writeChar = null;
    _notifyChar = null;
    _device = null;
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}
