import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../ble/ble_config_store.dart';

/// BLE 设备配置列表页。
///
/// 通用 BLE 设备连接配置——用户自填 UUID/协议参数。
class BleConfigPage extends StatefulWidget {
  const BleConfigPage({super.key});

  @override
  State<BleConfigPage> createState() => _BleConfigPageState();
}

class _BleConfigPageState extends State<BleConfigPage> {
  @override
  void initState() {
    super.initState();
    // 加载已存储的配置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BleConfigStore>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE 设备'),
        actions: [
          IconButton(
            icon: const Icon(Lucide.Plus),
            onPressed: () => _editConfig(context, null),
          ),
        ],
      ),
      body: Consumer<BleConfigStore>(
        builder: (context, store, _) {
          final configs = store.configs;
          if (configs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Lucide.Bluetooth, size: 48, color: cs.outline),
                  const SizedBox(height: 12),
                  Text(
                    '还没有设备配置',
                    style: TextStyle(color: cs.outline),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _editConfig(context, null),
                    child: const Text('添加设备'),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: configs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final c = configs[i];
              final isActive = c.id == store.activeId;
              return Card(
                color: isActive ? cs.primaryContainer : cs.surface,
                child: ListTile(
                  leading: Icon(Lucide.Bluetooth,
                      color: isActive ? cs.primary : cs.outline),
                  title: Text(c.name),
                  subtitle: Text(
                    '服务: ${c.serviceUuid.isEmpty ? "未填" : c.serviceUuid}\n'
                    '写: ${c.writeUuid.isEmpty ? "未填" : c.writeUuid}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  isThreeLine: true,
                  trailing: isActive
                      ? Icon(Lucide.Check, color: cs.primary)
                      : null,
                  onTap: () => _editConfig(context, c),
                  onLongPress: () => _confirmDelete(context, c.id, c.name),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _editConfig(BuildContext context, BleDeviceConfig? existing) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BleConfigEditPage(config: existing),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除配置'),
        content: Text('确定删除「$name」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              context.read<BleConfigStore>().delete(id);
              Navigator.pop(ctx);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// BLE 设备配置编辑页（新增 / 编辑）。
class BleConfigEditPage extends StatefulWidget {
  final BleDeviceConfig? config; // null = 新增

  const BleConfigEditPage({super.key, this.config});

  @override
  State<BleConfigEditPage> createState() => _BleConfigEditPageState();
}

class _BleConfigEditPageState extends State<BleConfigEditPage> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _serviceCtl;
  late final TextEditingController _writeCtl;
  late final TextEditingController _notifyCtl;
  late final TextEditingController _reconnectCtl;
  late final TextEditingController _retryCtl;
  late final TextEditingController _timeoutCtl;
  late final TextEditingController _keepAliveCtl;
  late final TextEditingController _stopDataCtl;
  late String _writeMethod;

  @override
  void initState() {
    super.initState();
    final c = widget.config;
    _nameCtl = TextEditingController(text: c?.name ?? '');
    _serviceCtl = TextEditingController(text: c?.serviceUuid ?? '');
    _writeCtl = TextEditingController(text: c?.writeUuid ?? '');
    _notifyCtl = TextEditingController(text: c?.notifyUuid ?? '');
    _reconnectCtl =
        TextEditingController(text: (c?.reconnectInterval ?? 3).toString());
    _retryCtl = TextEditingController(text: (c?.retryCount ?? 3).toString());
    _timeoutCtl =
        TextEditingController(text: (c?.connectTimeout ?? 10).toString());
    _keepAliveCtl = TextEditingController(
        text: (c?.keepAliveInterval ?? 0).toString());
    _stopDataCtl = TextEditingController(text: c?.stopData ?? '');
    _writeMethod = c?.writeMethod ?? 'withoutResponse';
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _serviceCtl.dispose();
    _writeCtl.dispose();
    _notifyCtl.dispose();
    _reconnectCtl.dispose();
    _retryCtl.dispose();
    _timeoutCtl.dispose();
    _keepAliveCtl.dispose();
    _stopDataCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final store = context.read<BleConfigStore>();
    final name = _nameCtl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写设备名称')),
      );
      return;
    }
    final config = BleDeviceConfig(
      id: widget.config?.id ?? '',
      name: name,
      serviceUuid: _serviceCtl.text.trim(),
      writeUuid: _writeCtl.text.trim(),
      notifyUuid: _notifyCtl.text.trim().isEmpty
          ? null
          : _notifyCtl.text.trim(),
      writeMethod: _writeMethod,
      reconnectInterval: int.tryParse(_reconnectCtl.text) ?? 3,
      retryCount: int.tryParse(_retryCtl.text) ?? 3,
      connectTimeout: int.tryParse(_timeoutCtl.text) ?? 10,
      keepAliveInterval: int.tryParse(_keepAliveCtl.text) ?? 0,
      stopData: _stopDataCtl.text.trim(),
    );
    if (widget.config == null) {
      // 新增
      final added = await store.add(
        name: name,
        serviceUuid: config.serviceUuid,
        writeUuid: config.writeUuid,
        notifyUuid: config.notifyUuid,
        writeMethod: config.writeMethod,
        reconnectInterval: config.reconnectInterval,
        retryCount: config.retryCount,
        connectTimeout: config.connectTimeout,
        keepAliveInterval: config.keepAliveInterval,
        stopData: config.stopData,
      );
      await store.setActive(added.id);
    } else {
      await store.update(config);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.config == null ? '添加设备' : '编辑设备'),
        actions: [
          IconButton(
            icon: const Icon(Lucide.Check),
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _field('设备名称', _nameCtl, '方便识别的名字'),
          _field('服务 UUID', _serviceCtl, '如 0000ffe0-0000-1000-8000-00805f9b34fb'),
          _field('写特征 UUID', _writeCtl, '如 0000ffe1-0000-1000-8000-00805f9b34fb'),
          _field('通知特征 UUID（可选）', _notifyCtl, '留空则不订阅通知'),
          const SizedBox(height: 16),
          Text('写入方式', style: TextStyle(color: cs.outline, fontSize: 13)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'withoutResponse', label: Text('无响应')),
              ButtonSegment(value: 'withResponse', label: Text('有响应')),
            ],
            selected: {_writeMethod},
            onSelectionChanged: (s) => setState(() => _writeMethod = s.first),
          ),
          const SizedBox(height: 16),
          _field('重连间隔（秒）', _reconnectCtl, '断线后多久重连'),
          _field('重发次数', _retryCtl, '单条指令重发几次'),
          _field('连接超时（秒）', _timeoutCtl, '连接多久算超时'),
          _field('保活重发间隔（毫秒）', _keepAliveCtl, '0=不保活，谜姬类设备填 200'),
          _field('停止指令 hex（可选）', _stopDataCtl, '停止时发的原始字节，如 0312f3...'),
          const SizedBox(height: 24),
          if (widget.config != null)
            FilledButton.tonalIcon(
              onPressed: () async {
                await context.read<BleConfigStore>().setActive(widget.config!.id);
                if (mounted) Navigator.pop(context);
              },
              icon: const Icon(Lucide.Check),
              label: const Text('设为当前设备'),
            ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctl, String hint) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: cs.outline, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: ctl,
            decoration: InputDecoration(
              hintText: hint,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}
