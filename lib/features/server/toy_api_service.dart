import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../server/server_config_store.dart';
import '../ble/ble_manager.dart';

/// 便笺消息。
class ChatNote {
  final int seq;
  final String from; // "me" 或对方
  final String msg;
  final String? ts;

  ChatNote({required this.seq, required this.from, required this.msg, this.ts});

  bool get isMine => from == 'me';
}

/// 收到的玩具指令。
class ToyCommand {
  final String cmd; // vibrate / stop / pattern / ping
  final Map<String, dynamic> args;

  ToyCommand({required this.cmd, required this.args});

  int? get speed => args['speed'] as int?;
  int? get duration => args['duration'] as int?;
  String? get pattern => args['pattern'] as String?;
  double? get interval => (args['interval'] as num?)?.toDouble();
  int? get loops => args['loops'] as int?;
}

/// 服务器联动服务。
///
/// 通过用户配置的 ServerConfig 轮询命令队列、读写便笺、推送指令。
/// 不写死任何地址或 token——全部从 ServerConfig 取。
class ToyApiService extends ChangeNotifier {
  ServerConfig? _config;
  BleManager? _ble;

  final List<ChatNote> _notes = [];
  final List<ToyCommand> _pendingCmds = [];
  bool _running = false;
  int _lastChatSeq = 0;
  int _lastCmdSeq = 0;

  Timer? _pollTimer;
  Timer? _chatTimer;

  List<ChatNote> get notes => List.unmodifiable(_notes);
  List<ToyCommand> get pendingCmds => List.unmodifiable(_pendingCmds);
  bool get isRunning => _running;

  /// 配置服务器和 BLE 管理器
  void configure(ServerConfig config, BleManager? ble) {
    _config = config;
    _ble = ble;
  }

  /// 开始轮询
  Future<void> start() async {
    if (_config == null || _running) return;
    _running = true;
    // 先拉一次便笺
    await _fetchChat();
    // 每 1s 轮询命令
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
    // 每 2s 拉便笺
    _chatTimer = Timer.periodic(const Duration(seconds: 2), (_) => _fetchChat());
    notifyListeners();
  }

  /// 停止轮询
  void stop() {
    _running = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _chatTimer?.cancel();
    _chatTimer = null;
    notifyListeners();
  }

  String _buildUrl(String? endpoint) {
    if (_config == null) return '';
    final base = _config!.baseUrl.endsWith('/')
        ? _config!.baseUrl.substring(0, _config!.baseUrl.length - 1)
        : _config!.baseUrl;
    final path = endpoint ?? '';
    return '$base$path';
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_config!.token.isNotEmpty) 'Authorization': 'Bearer ${_config!.token}',
      };

  /// 轮询命令队列（statusEndpoint = cmd-poll）
  Future<void> _poll() async {
    if (_config == null) return;
    final url = _buildUrl(_config!.statusEndpoint);
    if (url.isEmpty) return;
    try {
      final res = await http.get(
        Uri.parse(_config!.token.isNotEmpty
            ? '$url?token=${_config!.token}'
            : url),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      // 解析命令队列
      final queueNow = data['queue_now'];
      if (queueNow is Map<String, dynamic>) {
        final seq = queueNow['seq'] as int? ?? 0;
        if (seq > _lastCmdSeq) {
          _lastCmdSeq = seq;
          final cmd = queueNow['cmd'] as String? ?? '';
          final args = queueNow['args'] as Map<String, dynamic>? ?? {};
          if (cmd.isNotEmpty) {
            _pendingCmds.add(ToyCommand(cmd: cmd, args: args));
            _handleCommand(ToyCommand(cmd: cmd, args: args));
            notifyListeners();
          }
        }
      }

      // queue_recent（最近几条命令）
      final recent = data['queue_recent'];
      if (recent is List) {
        for (final r in recent) {
          if (r is Map<String, dynamic>) {
            final seq = r['seq'] as int? ?? 0;
            if (seq > _lastCmdSeq) {
              _lastCmdSeq = seq;
              final cmd = r['cmd'] as String? ?? '';
              final args = r['args'] as Map<String, dynamic>? ?? {};
              if (cmd.isNotEmpty) {
                _handleCommand(ToyCommand(cmd: cmd, args: args));
              }
            }
          }
        }
      }
    } catch (_) {
      // 网络错误静默，下次重试
    }
  }

  /// 处理收到的命令——子类可 override
  /// 默认实现：通知 ble_manager（如果连了）
  void _handleCommand(ToyCommand cmd) {
    // BLE 协议转换由 ble_manager 或子类处理
    // 这里只负责通知
  }

  /// 拉取便笺
  Future<void> _fetchChat() async {
    if (_config == null) return;
    final ep = _config!.chatEndpoint;
    if (ep == null || ep.isEmpty) return;
    final url = _buildUrl(ep);
    try {
      final res = await http.get(
        Uri.parse('$url?since=$_lastChatSeq'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body);
      final list = data is List ? data : (data['messages'] as List? ?? []);
      bool changed = false;
      for (final m in list) {
        if (m is Map<String, dynamic>) {
          final seq = m['seq'] as int? ?? 0;
          if (seq > _lastChatSeq) {
            _lastChatSeq = seq;
            _notes.add(ChatNote(
              seq: seq,
              from: m['from'] as String? ?? '',
              msg: m['msg'] as String? ?? '',
              ts: m['ts'] as String?,
            ));
            changed = true;
          }
        }
      }
      if (changed) notifyListeners();
    } catch (_) {}
  }

  /// 发送便笺
  Future<bool> sendChat(String msg) async {
    if (_config == null || msg.trim().isEmpty) return false;
    final ep = _config!.chatEndpoint;
    if (ep == null || ep.isEmpty) return false;
    final url = _buildUrl(ep);
    try {
      final body = jsonEncode({
        if (_config!.token.isNotEmpty) 'token': _config!.token,
        'from': 'me',
        'msg': msg.trim(),
      });
      final res = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: body,
      ).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 推送玩具指令
  Future<bool> pushCommand(String cmd, Map<String, dynamic> args) async {
    if (_config == null) return false;
    final ep = _config!.pushEndpoint;
    if (ep == null || ep.isEmpty) return false;
    final url = _buildUrl(ep);
    try {
      final body = jsonEncode({
        if (_config!.token.isNotEmpty) 'token': _config!.token,
        'cmd': cmd,
        'args': args,
      });
      final res = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: body,
      ).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 便捷方法：振动
  Future<bool> pushVibrate(int speed, {int duration = 0}) =>
      pushCommand('vibrate', {'speed': speed, 'duration': duration});

  /// 便捷方法：停止
  Future<bool> pushStop() => pushCommand('stop', {});

  /// 便捷方法：模式
  Future<bool> pushPattern(String pattern, double interval, int loops) =>
      pushCommand('pattern', {
        'pattern': pattern,
        'interval': interval,
        'loops': loops,
      });

  /// 清空便笺（本地）
  void clearNotes() {
    _notes.clear();
    _lastChatSeq = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
