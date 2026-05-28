// settings_page.dart
//
// 設定 Tab（mobile BottomNav 第三個 Tab）。
// 第一批：深淺色切換（淺 / 深 / 跟隨系統）+ 字級段階（小 / 標準 / 大 / 特大）。
// 兩者都讀寫 ThemeProvider（持久化在 shared_preferences），MaterialApp 即時跟著變。
// 後續第二批會再加「資料資訊區」與「關於頁」。

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  // 字級段階對應的中文標籤（值取自 ThemeProvider.textScaleSteps，順序一致）
  static const _textScaleLabels = ['小', '標準', '大', '特大'];

  @override
  Widget build(BuildContext context) {
    // watch：themeMode / textScale 改變時這頁的 SegmentedButton 選中狀態跟著更新
    final themeProvider = context.watch<ThemeProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('設定'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SectionHeader('主題外觀'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ThemeMode.light, label: Text('淺')),
                ButtonSegment(value: ThemeMode.dark, label: Text('深')),
                ButtonSegment(value: ThemeMode.system, label: Text('跟隨系統')),
              ],
              selected: {themeProvider.themeMode},
              onSelectionChanged: (selection) =>
                  context.read<ThemeProvider>().setThemeMode(selection.first),
            ),
          ),
          const Divider(height: 1),
          const _SectionHeader('字級'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SegmentedButton<double>(
              showSelectedIcon: false,
              segments: [
                for (var i = 0; i < ThemeProvider.textScaleSteps.length; i++)
                  ButtonSegment(
                    value: ThemeProvider.textScaleSteps[i],
                    label: Text(_textScaleLabels[i]),
                  ),
              ],
              selected: {themeProvider.textScale},
              onSelectionChanged: (selection) =>
                  context.read<ThemeProvider>().setTextScale(selection.first),
            ),
          ),
          // 即時預覽：這行字會跟著上面的字級設定一起放大縮小
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '預覽：分析師筆記的內文字級會像這樣呈現。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// 設定區塊的小標題（如「主題外觀」「字級」）。
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
