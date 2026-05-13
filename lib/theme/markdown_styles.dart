// markdown_styles.dart
//
// 共用的 MarkdownStyleSheet 工廠。
//
// 為什麼存在：flutter_markdown 預設樣式在 dark mode 下 blockquote 是
// 藍底白字（colorScheme.primary 系列），對比度極差幾乎看不清。
// 把客製樣式集中在這裡，HomePage 和 NotePage 共用一份規則。

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// App 共用的 markdown 樣式表。
MarkdownStyleSheet appMarkdownStyle(BuildContext context) {
  final theme = Theme.of(context);
  final colors = theme.colorScheme;
  final base = MarkdownStyleSheet.fromTheme(theme);

  return base.copyWith(
    // blockquote 在 dark mode 下原本對比差，這裡用 onSurface 確保可讀
    blockquote: theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurface,
      fontStyle: FontStyle.italic,
    ),
    blockquoteDecoration: BoxDecoration(
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(6),
      border: Border(
        left: BorderSide(color: colors.primary, width: 4),
      ),
    ),
    blockquotePadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    // 段落字距大一點點，閱讀長文較舒服
    p: theme.textTheme.bodyLarge,
    // 表格 border 用 outlineVariant，dark mode 下比預設黑色 border 柔和
    tableBorder: TableBorder.all(
      color: colors.outlineVariant,
      width: 1,
    ),
    tableHead: theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    ),
    // 改用內容自然寬度而非預設的 FlexColumnWidth(1.0)。
    // 為什麼：FlexColumnWidth 強制平均分配欄寬，在手機 (~390dp) 上 4 欄表格
    // 每欄分到 ~80dp，中文 cell 會被切成多行（每行 1-2 字）。
    // IntrinsicColumnWidth 讓每欄按內容寬度分配，cell 寬鬆 wrap 自然；
    // 缺點是寬表格在手機可能超出畫面（之後 App 版手機重新設計時會解決）。
    tableColumnWidth: const IntrinsicColumnWidth(),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    // 程式碼區塊用 container 色系，跟 blockquote 區分但保持風格一致
    codeblockDecoration: BoxDecoration(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(6),
    ),
    code: theme.textTheme.bodyMedium?.copyWith(
      backgroundColor: colors.surfaceContainerHighest,
      fontFamily: 'monospace',
    ),
  );
}
