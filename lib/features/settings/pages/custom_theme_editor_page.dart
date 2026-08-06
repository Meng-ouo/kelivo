import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/custom_theme.dart';
import '../../../theme/custom_theme_store.dart';
import '../../../theme/theme_factory.dart';
import '../../../theme/palettes.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../core/services/haptics.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

/// 自定义主题编辑器。
///
/// 功能：
/// - 列出所有保存的自定义主题
/// - 新建 / 编辑 / 删除 / 导入 / 导出
/// - 颜色选择器（HSV 滑杆 + hex 输入）
/// - 实时预览（试穿）→ 确认保存（落库）→ 一键应用
class CustomThemeEditorPage extends StatefulWidget {
  const CustomThemeEditorPage({super.key});

  @override
  State<CustomThemeEditorPage> createState() => _CustomThemeEditorPageState();
}

class _CustomThemeEditorPageState extends State<CustomThemeEditorPage> {
  @override
  void initState() {
    super.initState();
    // 加载存储
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomThemeStore>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final store = context.watch<CustomThemeStore>();
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Lucide.ArrowLeft, color: cs.onSurface, size: 22),
          onPressed: () {
            if (store.isTrying) {
              _showCancelDialog(context, store);
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
        title: Text(store.isTrying ? '编辑主题' : '自定义主题'),
        actions: [
          if (store.isTrying)
            TextButton(
              onPressed: () async {
                await store.commit();
                // 应用到全局
                _applyTheme(context, store);
                if (context.mounted) Navigator.of(context).maybePop();
              },
              child: Text(
                '保存',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: AppFontWeights.semibold,
                ),
              ),
            ),
        ],
      ),
      body: store.isTrying
          ? _buildEditor(context, store)
          : _buildThemeList(context, store, settings),
    );
  }

  // ── 主题列表 ──
  Widget _buildThemeList(
    BuildContext context,
    CustomThemeStore store,
    SettingsProvider settings,
  ) {
    final cs = Theme.of(context).colorScheme;
    final themes = store.themes;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 新建按钮
        _buildCard(
          context,
          child: ListTile(
            leading: Icon(Lucide.Plus, color: cs.primary),
            title: Text('新建主题'),
            onTap: () {
              store.createTheme(name: '新主题');
            },
          ),
        ),
        const SizedBox(height: 16),

        // 自定义主题列表
        if (themes.isNotEmpty) ...[
          Text(
            '我的主题',
            style: TextStyle(
              fontSize: 13,
              fontWeight: AppFontWeights.semibold,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          _buildCard(
            context,
            child: Column(
              children: [
                for (int i = 0; i < themes.length; i++) ...[
                  _themeRow(context, themes[i], store,
                      isActive: store.activeId == themes[i].id),
                  if (i < themes.length - 1) _divider(context),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 内置色板
        Text(
          '内置色板',
          style: TextStyle(
            fontSize: 13,
            fontWeight: AppFontWeights.semibold,
            color: cs.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        _buildCard(
          context,
          child: Column(
            children: [
              for (int i = 0; i < ThemePalettes.all.length; i++) ...[
                _paletteRow(context, ThemePalettes.all[i], settings,
                    isSelected: settings.themePaletteId ==
                        ThemePalettes.all[i].id),
                if (i < ThemePalettes.all.length - 1) _divider(context),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _themeRow(
    BuildContext context,
    CustomTheme theme,
    CustomThemeStore store, {
    required bool isActive,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        Haptics.soft();
        store.edit(theme);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 颜色预览圆点
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(theme.light.primary),
                    Color(theme.dark.primary),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: Theme.of(context).brightness == Brightness.dark
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(theme.name, style: const TextStyle(fontSize: 15)),
                  Text(
                    '${_hex(Color(theme.light.primary))} / ${_hex(Color(theme.dark.primary))}',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              Icon(Lucide.Check, size: 18, color: cs.primary)
            else
              const SizedBox(width: 18),
            // 删除
            if (!isActive)
              GestureDetector(
                onTap: () => _confirmDelete(context, store, theme.id),
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(Lucide.Trash2,
                      size: 16, color: cs.onSurface.withValues(alpha: 0.4)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _paletteRow(
    BuildContext context,
    ThemePalette palette,
    SettingsProvider settings, {
    required bool isSelected,
  }) {
    final cs = Theme.of(context).colorScheme;
    final title = Localizations.localeOf(context).languageCode == 'zh'
        ? palette.displayNameZh
        : palette.displayNameEn;
    return InkWell(
      onTap: () {
        Haptics.soft();
        settings.setThemePalette(palette.id);
        // 切回内置色板时清除自定义主题
        context.read<CustomThemeStore>().clearActive();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: palette.light.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 15)),
            ),
            if (isSelected)
              Icon(Lucide.Check, size: 18, color: cs.primary)
            else
              const SizedBox(width: 18),
          ],
        ),
      ),
    );
  }

  // ── 编辑器 ──
  Widget _buildEditor(BuildContext context, CustomThemeStore store) {
    final theme = store.tryingOn!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = isDark ? theme.toDarkColorScheme() : theme.toLightColorScheme();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 预览卡
        _buildPreviewCard(context, cs),
        const SizedBox(height: 20),

        // 主题名
        _buildCard(
          context,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text('名称',
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.6))),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: theme.name)
                      ..selection = TextSelection.fromPosition(
                        TextPosition(offset: theme.name.length),
                      ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: TextStyle(color: cs.onSurface),
                    onChanged: (v) => store.updateTryingName(v),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 日间颜色
        _buildColorSection(
          context,
          store,
          theme,
          isLight: true,
          title: '日间配色',
        ),
        const SizedBox(height: 20),

        // 夜间颜色
        _buildColorSection(
          context,
          store,
          theme,
          isLight: false,
          title: '夜间配色',
        ),
      ],
    );
  }

  Widget _buildPreviewCard(BuildContext context, ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.3),
          width: 0.6,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // 顶栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            color: cs.surface,
            child: Row(
              children: [
                Icon(Lucide.ArrowLeft, size: 20, color: cs.onSurface),
                const SizedBox(width: 16),
                Text('预览',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: AppFontWeights.semibold,
                      color: cs.onSurface,
                    )),
              ],
            ),
          ),
          Divider(height: 0, color: cs.outlineVariant.withValues(alpha: 0.15)),
          // 消息气泡
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // AI 气泡
                Container(
                  constraints: const BoxConstraints(maxWidth: 240),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceVariant.withValues(alpha: 0.3),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                      bottomLeft: Radius.circular(4),
                    ),
                  ),
                  child: Text(
                    '这是预览效果。改颜色实时看到变化。',
                    style: TextStyle(fontSize: 14, color: cs.onSurface),
                  ),
                ),
                const SizedBox(height: 12),
                // 用户气泡
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 240),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                    child: Text(
                      '好看吗',
                      style: TextStyle(fontSize: 14, color: cs.onPrimary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 按钮
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Center(
                          child: Text('主按钮',
                              style: TextStyle(
                                  color: cs.onPrimary, fontSize: 15)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Lucide.Heart, size: 20, color: cs.onSecondaryContainer),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorSection(
    BuildContext context,
    CustomThemeStore store,
    CustomTheme theme, {
    required bool isLight,
    required String title,
  }) {
    final cs = Theme.of(context).colorScheme;
    final colorScheme = isLight ? theme.light : theme.dark;
    final colors = colorScheme.toJson();

    // 只显示常用颜色
    final displayKeys = <String>[
      'primary',
      'onPrimary',
      'primaryContainer',
      'secondary',
      'surface',
      'onSurface',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: AppFontWeights.semibold,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        _buildCard(
          context,
          child: Column(
            children: [
              for (int i = 0; i < displayKeys.length; i++) ...[
                _colorRow(
                  context,
                  store,
                  isLight: isLight,
                  key: displayKeys[i],
                  value: colors[displayKeys[i]] as int,
                ),
                if (i < displayKeys.length - 1) _divider(context),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _colorRow(
    BuildContext context,
    CustomThemeStore store, {
    required bool isLight,
    required String key,
    required int value,
  }) {
    final cs = Theme.of(context).colorScheme;
    final labels = <String, String>{
      'primary': '主色',
      'onPrimary': '主色文字',
      'primaryContainer': '主色容器',
      'onPrimaryContainer': '容器文字',
      'secondary': '次要色',
      'onSecondary': '次要文字',
      'secondaryContainer': '次要容器',
      'onSecondaryContainer': '次要容器文字',
      'tertiary': '第三色',
      'surface': '背景',
      'onSurface': '正文文字',
      'onSurfaceVariant': '次要文字',
      'outline': '描边',
      'outlineVariant': '次要描边',
      'inverseSurface': '反色背景',
      'onInverseSurface': '反色文字',
      'inversePrimary': '反色主色',
    };

    return InkWell(
      onTap: () => _showColorPicker(context, store, isLight, key, value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 颜色块
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Color(value),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.2),
                  width: 0.6,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                labels[key] ?? key,
                style: TextStyle(fontSize: 15, color: cs.onSurface),
              ),
            ),
            Text(
              _hex(Color(value)),
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Lucide.ChevronRight,
                size: 16, color: cs.onSurface.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  void _showColorPicker(
    BuildContext context,
    CustomThemeStore store,
    bool isLight,
    String key,
    int currentValue,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ColorPickerSheet(
        initialColor: Color(currentValue),
        title: key,
        onColorChanged: (color) {
          store.updateTryingColor(
            isLight: isLight,
            key: key,
            value: color.value,
          );
        },
      ),
    );
  }

  // ── 辅助 ──
  void _applyTheme(BuildContext context, CustomThemeStore store) {
    // commit 已经设置了 activeId + notifyListeners，
    // main.dart watch 了 CustomThemeStore 会自动更新 ThemeData
  }

  void _showCancelDialog(BuildContext context, CustomThemeStore store) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放弃改动？'),
        content: const Text('试穿中的改动还没保存，确定要放弃吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () {
              store.cancelTryOn();
              Navigator.of(ctx).pop();
              Navigator.of(context).maybePop();
            },
            child: const Text('放弃'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, CustomThemeStore store, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除主题？'),
        content: const Text('删除后不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              store.delete(id);
              Navigator.of(ctx).pop();
            },
            child: Text(
              '删除',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.08),
          width: 0.6,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _divider(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Divider(
      height: 6,
      thickness: 0.6,
      indent: 12,
      endIndent: 12,
      color: cs.outlineVariant.withValues(alpha: 0.15),
    );
  }

  String _hex(Color c) =>
      '#${c.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

/// HSV 颜色选择器弹窗。
class _ColorPickerSheet extends StatefulWidget {
  final Color initialColor;
  final String title;
  final ValueChanged<Color> onColorChanged;

  const _ColorPickerSheet({
    required this.initialColor,
    required this.title,
    required this.onColorChanged,
  });

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initialColor);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _hsv.toColor();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖动条
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // 颜色预览
          Container(
            width: double.infinity,
            height: 80,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 8),

          // hex 值
          Text(
            '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: AppFontWeights.semibold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          // HSV 滑杆
          _buildSlider('色相', _hsv.hue, 360, (v) {
            setState(() {
              _hsv = _hsv.withHue(v);
              widget.onColorChanged(_hsv.toColor());
            });
          }, hueBar: true),
          _buildSlider('饱和度', _hsv.saturation, 1, (v) {
            setState(() {
              _hsv = _hsv.withSaturation(v);
              widget.onColorChanged(_hsv.toColor());
            });
          }),
          _buildSlider('明度', _hsv.value, 1, (v) {
            setState(() {
              _hsv = _hsv.withValue(v);
              widget.onColorChanged(_hsv.toColor());
            });
          }),

          const SizedBox(height: 16),

          // 完成
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('完成'),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double max,
    ValueChanged<double> onChanged, {
    bool hueBar = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6))),
          ),
          Expanded(
            child: hueBar
                ? SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 12,
                      activeTrackColor: Colors.transparent,
                      inactiveTrackColor: Colors.transparent,
                      thumbColor: Colors.white,
                      overlayShape: SliderComponentShape.noOverlay,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 10),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 12,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFF0000),
                                Color(0xFFFFFF00),
                                Color(0xFF00FF00),
                                Color(0xFF00FFFF),
                                Color(0xFF0000FF),
                                Color(0xFFFF00FF),
                                Color(0xFFFF0000),
                              ],
                            ),
                          ),
                        ),
                        Slider(
                          value: value,
                          max: max,
                          onChanged: onChanged,
                        ),
                      ],
                    ),
                  )
                : Slider(
                    value: value,
                    max: max,
                    activeColor: _hsv.toColor(),
                    onChanged: onChanged,
                  ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              max == 1
                  ? '${(value * 100).round()}%'
                  : value.round().toString(),
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)),
            ),
          ),
        ],
      ),
    );
  }
}
