import 'dart:convert';
import 'package:flutter/material.dart';

/// 自定义主题模型。
///
/// 抄 Polaris 的分层思路：主题 = 一组颜色 token，
/// 可以保存多套、切换、编辑、一键应用。
/// 存成 JSON 序列化，走 SharedPreferences 持久化。
class CustomTheme {
  final String id;
  final String name;
  final CustomColorScheme light;
  final CustomColorScheme dark;
  final DateTime createdAt;
  final DateTime updatedAt;

  CustomTheme({
    required this.id,
    required this.name,
    required this.light,
    required this.dark,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomTheme.create({
    required String name,
    CustomColorScheme? light,
    CustomColorScheme? dark,
  }) {
    final now = DateTime.now();
    return CustomTheme(
      id: 'ct_${now.millisecondsSinceEpoch}',
      name: name,
      light: light ?? CustomColorScheme.creamBerryLight(),
      dark: dark ?? CustomColorScheme.creamBerryDark(),
    );
  }

  CustomTheme copyWith({
    String? name,
    CustomColorScheme? light,
    CustomColorScheme? dark,
  }) {
    return CustomTheme(
      id: id,
      name: name ?? this.name,
      light: light ?? this.light,
      dark: dark ?? this.dark,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'light': light.toJson(),
        'dark': dark.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory CustomTheme.fromJson(Map<String, dynamic> json) {
    return CustomTheme(
      id: json['id'] as String,
      name: json['name'] as String,
      light: CustomColorScheme.fromJson(json['light'] as Map<String, dynamic>),
      dark: CustomColorScheme.fromJson(json['dark'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  static CustomTheme fromJsonString(String s) =>
      CustomTheme.fromJson(jsonDecode(s) as Map<String, dynamic>);

  /// 转成 Flutter ColorScheme
  ColorScheme toLightColorScheme() => light.toColorScheme(Brightness.light);
  ColorScheme toDarkColorScheme() => dark.toColorScheme(Brightness.dark);
}

/// 可序列化的颜色方案。对应 Flutter 的 ColorScheme。
class CustomColorScheme {
  final int primary;
  final int onPrimary;
  final int primaryContainer;
  final int onPrimaryContainer;
  final int secondary;
  final int onSecondary;
  final int secondaryContainer;
  final int onSecondaryContainer;
  final int tertiary;
  final int onTertiary;
  final int tertiaryContainer;
  final int onTertiaryContainer;
  final int surface;
  final int onSurface;
  final int onSurfaceVariant;
  final int outline;
  final int outlineVariant;
  final int inverseSurface;
  final int onInverseSurface;
  final int inversePrimary;

  const CustomColorScheme({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.onTertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.surface,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.inversePrimary,
  });

  /// 奶霜莓粉日间默认值
  factory CustomColorScheme.creamBerryLight() => const CustomColorScheme(
        primary: 0xFFD98B9A,
        onPrimary: 0xFFFFFFFF,
        primaryContainer: 0xFFF5D5DC,
        onPrimaryContainer: 0xFF5C2238,
        secondary: 0xFF8BB4C9,
        onSecondary: 0xFFFFFFFF,
        secondaryContainer: 0xFFD6E8F0,
        onSecondaryContainer: 0xFF1A3540,
        tertiary: 0xFFC9A0B4,
        onTertiary: 0xFFFFFFFF,
        tertiaryContainer: 0xFFF0E0E8,
        onTertiaryContainer: 0xFF3A1A2A,
        surface: 0xFFF9F5F2,
        onSurface: 0xFF2D2424,
        onSurfaceVariant: 0xFF5C504C,
        outline: 0xFFB0A0A0,
        outlineVariant: 0xFFD8D0CC,
        inverseSurface: 0xFF2D2424,
        onInverseSurface: 0xFFF9F5F2,
        inversePrimary: 0xFFD98B9A,
      );

  /// 奶霜莓粉夜间默认值
  factory CustomColorScheme.creamBerryDark() => const CustomColorScheme(
        primary: 0xFFE8A5B4,
        onPrimary: 0xFF3A1520,
        primaryContainer: 0xFF8A5560,
        onPrimaryContainer: 0xFFF5D5DC,
        secondary: 0xFF9BC5D9,
        onSecondary: 0xFF1A3540,
        secondaryContainer: 0xFF3A5560,
        onSecondaryContainer: 0xFFD6E8F0,
        tertiary: 0xFFD4B0C0,
        onTertiary: 0xFF3A1A2A,
        tertiaryContainer: 0xFF5A3848,
        onTertiaryContainer: 0xFFF0E0E8,
        surface: 0xFF1F1A1A,
        onSurface: 0xFFF0EAE6,
        onSurfaceVariant: 0xFFC0B8B4,
        outline: 0xFF8A807C,
        outlineVariant: 0xFF454040,
        inverseSurface: 0xFFF0EAE6,
        onInverseSurface: 0xFF1F1A1A,
        inversePrimary: 0xFFD98B9A,
      );

  /// 从现有 ColorScheme 提取
  factory CustomColorScheme.fromColorScheme(ColorScheme cs) =>
      CustomColorScheme(
        primary: cs.primary.value,
        onPrimary: cs.onPrimary.value,
        primaryContainer: cs.primaryContainer.value,
        onPrimaryContainer: cs.onPrimaryContainer.value,
        secondary: cs.secondary.value,
        onSecondary: cs.onSecondary.value,
        secondaryContainer: cs.secondaryContainer.value,
        onSecondaryContainer: cs.onSecondaryContainer.value,
        tertiary: cs.tertiary.value,
        onTertiary: cs.onTertiary.value,
        tertiaryContainer: cs.tertiaryContainer.value,
        onTertiaryContainer: cs.onTertiaryContainer.value,
        surface: cs.surface.value,
        onSurface: cs.onSurface.value,
        onSurfaceVariant: cs.onSurfaceVariant.value,
        outline: cs.outline.value,
        outlineVariant: cs.outlineVariant.value,
        inverseSurface: cs.inverseSurface.value,
        onInverseSurface: cs.onInverseSurface.value,
        inversePrimary: cs.inversePrimary.value,
      );

  Map<String, dynamic> toJson() => {
        'primary': primary,
        'onPrimary': onPrimary,
        'primaryContainer': primaryContainer,
        'onPrimaryContainer': onPrimaryContainer,
        'secondary': secondary,
        'onSecondary': onSecondary,
        'secondaryContainer': secondaryContainer,
        'onSecondaryContainer': onSecondaryContainer,
        'tertiary': tertiary,
        'onTertiary': onTertiary,
        'tertiaryContainer': tertiaryContainer,
        'onTertiaryContainer': onTertiaryContainer,
        'surface': surface,
        'onSurface': onSurface,
        'onSurfaceVariant': onSurfaceVariant,
        'outline': outline,
        'outlineVariant': outlineVariant,
        'inverseSurface': inverseSurface,
        'onInverseSurface': onInverseSurface,
        'inversePrimary': inversePrimary,
      };

  factory CustomColorScheme.fromJson(Map<String, dynamic> json) =>
      CustomColorScheme(
        primary: json['primary'] as int,
        onPrimary: json['onPrimary'] as int,
        primaryContainer: json['primaryContainer'] as int,
        onPrimaryContainer: json['onPrimaryContainer'] as int,
        secondary: json['secondary'] as int,
        onSecondary: json['onSecondary'] as int,
        secondaryContainer: json['secondaryContainer'] as int,
        onSecondaryContainer: json['onSecondaryContainer'] as int,
        tertiary: json['tertiary'] as int,
        onTertiary: json['onTertiary'] as int,
        tertiaryContainer: json['tertiaryContainer'] as int,
        onTertiaryContainer: json['onTertiaryContainer'] as int,
        surface: json['surface'] as int,
        onSurface: json['onSurface'] as int,
        onSurfaceVariant: json['onSurfaceVariant'] as int,
        outline: json['outline'] as int,
        outlineVariant: json['outlineVariant'] as int,
        inverseSurface: json['inverseSurface'] as int,
        onInverseSurface: json['onInverseSurface'] as int,
        inversePrimary: json['inversePrimary'] as int,
      );

  ColorScheme toColorScheme(Brightness brightness) {
    return ColorScheme(
      brightness: brightness,
      primary: Color(primary),
      onPrimary: Color(onPrimary),
      primaryContainer: Color(primaryContainer),
      onPrimaryContainer: Color(onPrimaryContainer),
      secondary: Color(secondary),
      onSecondary: Color(onSecondary),
      secondaryContainer: Color(secondaryContainer),
      onSecondaryContainer: Color(onSecondaryContainer),
      tertiary: Color(tertiary),
      onTertiary: Color(onTertiary),
      tertiaryContainer: Color(tertiaryContainer),
      onTertiaryContainer: Color(onTertiaryContainer),
      surface: Color(surface),
      onSurface: Color(onSurface),
      onSurfaceVariant: Color(onSurfaceVariant),
      outline: Color(outline),
      outlineVariant: Color(outlineVariant),
      inverseSurface: Color(inverseSurface),
      onInverseSurface: Color(onInverseSurface),
      inversePrimary: Color(inversePrimary),
      error: brightness == Brightness.light
          ? const Color(0xFFBB0947)
          : const Color(0xFFFCB4BD),
      onError: brightness == Brightness.light
          ? const Color(0xFFFFFFFF)
          : const Color(0xFF670023),
      errorContainer: brightness == Brightness.light
          ? const Color(0xFFFDDADE)
          : const Color(0xFF910034),
      onErrorContainer: brightness == Brightness.light
          ? const Color(0xFF400013)
          : const Color(0xFFFCB4BD),
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
      surfaceTint: Color(primary),
    );
  }

  CustomColorScheme copyWithColor(String key, int value) {
    final m = Map<String, int>.from(toJson());
    m[key] = value;
    return CustomColorScheme.fromJson(m.map((k, v) => MapEntry(k, v)));
  }
}
