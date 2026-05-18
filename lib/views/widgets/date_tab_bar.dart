// date_tab_bar.dart
//
// 共用的日期 TabBar——HomePage（對照檔）和 NotePage（個別分析師）都用。
// Tab 顯示日期；如果該 entry 有有意義副標（例如「盤前 · 追高警告場」），會顯示成第二行。

import 'package:flutter/material.dart';

import '../../models/note_entry.dart';

class DateTabBar extends StatelessWidget implements PreferredSizeWidget {
  const DateTabBar({super.key, required this.entries});

  final List<NoteEntry> entries;

  // 同檔案內任一 entry 有副標就把 TabBar 撐成兩行高（保持節奏一致，否則 Tab 高度不一）
  bool get _anyHasNote => entries.any((entry) => entry.displayNote != null);

  @override
  Size get preferredSize => Size.fromHeight(_anyHasNote ? 64 : 48);

  @override
  Widget build(BuildContext context) {
    return Material(
      // Material 而非 Container：讓 TabBar 的水波紋正確顯示
      color: Theme.of(context).colorScheme.surface,
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        tabs: entries
            .map((entry) => _DateTab(entry: entry, expandedHeight: _anyHasNote))
            .toList(),
      ),
    );
  }
}

class _DateTab extends StatelessWidget {
  const _DateTab({required this.entry, required this.expandedHeight});

  final NoteEntry entry;

  /// 若同檔案內有任一 Tab 有副標，全部 Tab 都撐高保持一致——避免 TabBar 高度抖動
  final bool expandedHeight;

  @override
  Widget build(BuildContext context) {
    final displayNote = entry.displayNote;
    final theme = Theme.of(context);
    return SizedBox(
      height: expandedHeight ? 56 : 40,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            entry.date,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (displayNote != null) ...[
            const SizedBox(height: 2),
            Text(
              displayNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
