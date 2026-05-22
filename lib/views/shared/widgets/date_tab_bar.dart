// date_tab_bar.dart
//
// 共用的日期 TabBar——HomePage（對照檔）和 NotePage（個別分析師）都用。
// Tab 只顯示「日期」一行，不放副標題：
// - 副標（如「盤前 · 追高警告場」）放進 Tab 會讓 Tab 過寬、且同日多篇會出現重複日期。
// - NotePage 已先依日期把多篇合併成一個 Tab，篇與篇改由內容上方的 segment 切換。

import 'package:flutter/material.dart';

import '../../../models/note_entry.dart';

class DateTabBar extends StatelessWidget implements PreferredSizeWidget {
  const DateTabBar({super.key, required this.entries});

  /// 一筆 entry 對應一個日期 Tab。呼叫端（NotePage）需先依日期去重，
  /// 每個日期只傳一筆代表 entry；HomePage 的對照檔本來就一日一筆。
  final List<NoteEntry> entries;

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      // Material 而非 Container：讓 TabBar 的水波紋正確顯示
      color: theme.colorScheme.surface,
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        tabs: entries
            .map(
              (entry) => Tab(
                height: 40,
                child: Text(
                  entry.date,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
