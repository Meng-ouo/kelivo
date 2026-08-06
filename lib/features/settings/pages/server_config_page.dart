import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../server/server_config_store.dart';

/// 服务器配置列表页。
///
/// 通用服务器联动配置——用户自填 URL/token/端点。
class ServerConfigPage extends StatefulWidget {
  const ServerConfigPage({super.key});

  @override
  State<ServerConfigPage> createState() => _ServerConfigPageState();
}

class _ServerConfigPageState extends State<ServerConfigPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServerConfigStore>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('服务器'),
        actions: [
          IconButton(
            icon: const Icon(Lucide.Plus),
            onPressed: () => _editConfig(context, null),
          ),
        ],
      ),
      body: Consumer<ServerConfigStore>(
        builder: (context, store, _) {
          final configs = store.configs;
          if (configs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Lucide.Server, size: 48, color: cs.outline),
                  const SizedBox(height: 12),
                  Text(
                    '还没有服务器配置',
                    style: TextStyle(color: cs.outline),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _editConfig(context, null),
                    child: const Text('添加服务器'),
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
                  leading: Icon(Lucide.Server,
                      color: isActive ? cs.primary : cs.outline),
                  title: Text(c.name),
                  subtitle: Text(
                    '${c.baseUrl.isEmpty ? "未填地址" : c.baseUrl}'
                    '${c.enabled ? "" : "（已禁用）"}',
                    style: const TextStyle(fontSize: 12),
                  ),
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

  void _editConfig(BuildContext context, ServerConfig? existing) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ServerConfigEditPage(config: existing),
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
              context.read<ServerConfigStore>().delete(id);
              Navigator.pop(ctx);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// 服务器配置编辑页（新增 / 编辑）。
class ServerConfigEditPage extends StatefulWidget {
  final ServerConfig? config;

  const ServerConfigEditPage({super.key, this.config});

  @override
  State<ServerConfigEditPage> createState() => _ServerConfigEditPageState();
}

class _ServerConfigEditPageState extends State<ServerConfigEditPage> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _urlCtl;
  late final TextEditingController _tokenCtl;
  late final TextEditingController _chatCtl;
  late final TextEditingController _pushCtl;
  late final TextEditingController _statusCtl;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    final c = widget.config;
    _nameCtl = TextEditingController(text: c?.name ?? '');
    _urlCtl = TextEditingController(text: c?.baseUrl ?? '');
    _tokenCtl = TextEditingController(text: c?.token ?? '');
    _chatCtl = TextEditingController(text: c?.chatEndpoint ?? '');
    _pushCtl = TextEditingController(text: c?.pushEndpoint ?? '');
    _statusCtl = TextEditingController(text: c?.statusEndpoint ?? '');
    _enabled = c?.enabled ?? true;
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _urlCtl.dispose();
    _tokenCtl.dispose();
    _chatCtl.dispose();
    _pushCtl.dispose();
    _statusCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final store = context.read<ServerConfigStore>();
    final name = _nameCtl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写名称')),
      );
      return;
    }
    final config = ServerConfig(
      id: widget.config?.id ?? '',
      name: name,
      baseUrl: _urlCtl.text.trim(),
      token: _tokenCtl.text.trim(),
      chatEndpoint: _chatCtl.text.trim().isEmpty ? null : _chatCtl.text.trim(),
      pushEndpoint:
          _pushCtl.text.trim().isEmpty ? null : _pushCtl.text.trim(),
      statusEndpoint:
          _statusCtl.text.trim().isEmpty ? null : _statusCtl.text.trim(),
      enabled: _enabled,
    );
    if (widget.config == null) {
      final added = await store.add(
        name: name,
        baseUrl: config.baseUrl,
        token: config.token,
        chatEndpoint: config.chatEndpoint,
        pushEndpoint: config.pushEndpoint,
        statusEndpoint: config.statusEndpoint,
        enabled: config.enabled,
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
        title: Text(widget.config == null ? '添加服务器' : '编辑服务器'),
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
          _field('名称', _nameCtl, '方便识别的名字'),
          _field('服务器地址', _urlCtl, '如 https://example.com'),
          _field('Token', _tokenCtl, '认证凭据（可选）'),
          _field('聊天端点（可选）', _chatCtl, '相对路径，如 /api/chat'),
          _field('指令端点（可选）', _pushCtl, '相对路径，如 /api/push'),
          _field('状态端点（可选）', _statusCtl, '相对路径，如 /api/status'),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('启用此服务器'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          const SizedBox(height: 24),
          if (widget.config != null)
            FilledButton.tonalIcon(
              onPressed: () async {
                await context.read<ServerConfigStore>().setActive(widget.config!.id);
                if (mounted) Navigator.pop(context);
              },
              icon: const Icon(Lucide.Check),
              label: const Text('设为当前服务器'),
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
