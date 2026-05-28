// settings_page.dart
//
// 設定頁（mobile：AppShell BottomNav 第三個 Tab；web：HomePage 右上角齒輪 push 進來）。
// 四個區塊：
//   1. 主題外觀：深淺色切換（淺 / 深 / 跟隨系統）
//   2. 字級：段階（小 / 標準 / 大 / 特大）
//   3. 資料資訊：notes.json 最後更新時間 + 內容統計 + schema 版本
//   4. 關於：App 版本號 + GitHub 原始碼連結 + 免責聲明
// 1、2 讀寫 ThemeProvider（持久化在 shared_preferences）；3 讀 NotesApiService 的
// 快取 NotesIndex；4 用 package_info_plus 取版本、url_launcher 開連結。

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/notes_index.dart';
import '../../providers/theme_provider.dart';
import '../../services/notes_api_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  // 字級段階對應的中文標籤（值取自 ThemeProvider.textScaleSteps，順序一致）
  static const _textScaleLabels = ['小', '標準', '大', '特大'];
  static const _githubUrl = 'https://github.com/gary8107/stockAnalysis';

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
          const Divider(height: 1),
          const _SectionHeader('資料資訊'),
          const _DataInfoSection(),
          const Divider(height: 1),
          const _SectionHeader('關於'),
          const _AboutSection(githubUrl: _githubUrl),
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

/// 資料資訊：讀 NotesApiService 的快取 NotesIndex，顯示最後更新時間 / 內容統計 / 版本。
/// 用 FutureBuilder 直接接 load()（已快取，不會額外打 HTTP）。
class _DataInfoSection extends StatelessWidget {
  const _DataInfoSection();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NotesIndex>(
      future: context.read<NotesApiService>().load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ListTile(
            title: Text('最後更新'),
            trailing: Text('載入中…'),
          );
        }
        final index = snapshot.data;
        if (index == null) {
          return const ListTile(
            title: Text('資料資訊'),
            subtitle: Text('資料載入失敗'),
          );
        }
        return Column(
          children: [
            ListTile(
              title: const Text('最後更新'),
              trailing: Text(_formatDateTime(index.generatedAt)),
            ),
            ListTile(
              title: const Text('內容'),
              subtitle: Text(
                '${index.analysts.length} 位分析師 · '
                '${index.notes.length} 筆筆記 · '
                '${index.comparisons.length} 筆對照',
              ),
            ),
            ListTile(
              title: const Text('資料格式版本'),
              trailing: Text('v${index.version}'),
            ),
          ],
        );
      },
    );
  }

  // generatedAt 是 UTC（build script 產 JSON 的時間），轉本地時間顯示 yyyy-MM-dd HH:mm
  static String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

/// 關於：App 版本（package_info_plus）+ GitHub 連結（url_launcher）+ 免責聲明。
class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.githubUrl});

  final String githubUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        FutureBuilder<PackageInfo?>(
          future: _loadPackageInfo(),
          builder: (context, snapshot) {
            final info = snapshot.data;
            final versionText =
                info == null ? '—' : '${info.version} (${info.buildNumber})';
            return ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('App 版本'),
              trailing: Text(versionText),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.code),
          title: const Text('原始碼'),
          subtitle: Text(githubUrl),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => _openUrl(context, githubUrl),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Text(
            '本 App 內容彙整自台股投顧分析師公開 YouTube 影片，僅供個人筆記與技術展示用途。'
            '所有個股皆非投資建議，投資人應獨立判斷、自負投資風險。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  // 包 try/catch：測試環境沒有 plugin 時回 null（顯示「—」），不丟出未捕捉錯誤。
  static Future<PackageInfo?> _loadPackageInfo() async {
    try {
      return await PackageInfo.fromPlatform();
    } catch (_) {
      return null;
    }
  }

  // 先抓 ScaffoldMessenger 再 await，避免 use_build_context_synchronously。
  static Future<void> _openUrl(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) {
        messenger.showSnackBar(const SnackBar(content: Text('無法開啟連結')));
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('無法開啟連結')));
    }
  }
}
