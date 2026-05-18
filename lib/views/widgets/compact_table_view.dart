// compact_table_view.dart
//
// 取代 flutter_markdown 的 table 渲染，解決三件事：
// 1. 表格不再水平捲動——固定欄寬，內容超出用 ellipsis 截斷
// 2. 點 cell 跳出整列 dialog，顯示所有欄位完整內容（保留 inline markdown 樣式）
// 3. 解除「滑表格邊邊誤觸 TabBar 切換日期」的 UX 痛點
//
// 為什麼 cell 用純文字 + ellipsis、不用 MarkdownBody：
// MarkdownBody 內部 wrap 多行、無法乾淨 ellipsis；要在 cell 內保留粗體
// 必須自寫 inline markdown parser 輸出 TextSpan，工作量遠大於這版需求。
// 折衷：cell 把 inline markdown 樣式 strip 掉只看文字、dialog 內用
// MarkdownBody 把粗體/連結等補回——「快覽 cell + 詳看 dialog」分工。

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../models/note_block.dart';
import '../../theme/markdown_styles.dart';

class CompactTableView extends StatelessWidget {
  const CompactTableView({super.key, required this.table});

  final TableBlock table;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final headerStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        );
    final cellStyle = Theme.of(context).textTheme.bodyMedium;

    return Table(
      // 為什麼用 FlexColumnWidth(1) 而非 IntrinsicColumnWidth：
      // Intrinsic 會讓表格寬度跟著內容變、可能再次超出畫面；FlexColumnWidth(1)
      // 每欄等寬、總寬永遠等於父容器寬度——「固定不滑動」最直觀的實作
      defaultColumnWidth: const FlexColumnWidth(1),
      border: TableBorder.all(color: colors.outlineVariant, width: 1),
      children: [
        TableRow(
          decoration: BoxDecoration(color: colors.surfaceContainerHigh),
          children: [
            for (final header in table.headers)
              _HeaderCell(text: header, style: headerStyle),
          ],
        ),
        for (var rowIndex = 0; rowIndex < table.rows.length; rowIndex++)
          TableRow(
            children: [
              for (var colIndex = 0;
                  colIndex < table.headers.length;
                  colIndex++)
                _BodyCell(
                  text: table.rows[rowIndex][colIndex],
                  style: cellStyle,
                  onTap: () => _showRowDialog(
                    context,
                    headers: table.headers,
                    row: table.rows[rowIndex],
                    focusedColumn: colIndex,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _showRowDialog(
    BuildContext context, {
    required List<String> headers,
    required List<String> row,
    required int focusedColumn,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => _RowDetailDialog(
        headers: headers,
        row: row,
        focusedColumn: focusedColumn,
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.text, required this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        // header 通常很短不會被截，但保險起見也加 ellipsis
        _stripMarkdownInline(text),
        style: style,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  const _BodyCell({
    required this.text,
    required this.style,
    required this.onTap,
  });

  final String text;
  final TextStyle? style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          _stripMarkdownInline(text),
          style: style,
          // maxLines: 1 + ellipsis 是「固定不滑動」的核心——每個 cell 都同高
          // 不會把表格撐高，內容超出走 ... 由 dialog 補完整資訊
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _RowDetailDialog extends StatelessWidget {
  const _RowDetailDialog({
    required this.headers,
    required this.row,
    required this.focusedColumn,
  });

  final List<String> headers;
  final List<String> row;

  /// 使用者點的那欄——dialog 內視覺上強調這欄，但其他欄也一起顯示
  /// 讓使用者一次看到整列脈絡
  final int focusedColumn;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final markdownStyle = appMarkdownStyle(context);

    return AlertDialog(
      // title 用第一欄（通常是分類標籤 / 個股名）讓使用者知道在看哪列
      title: Text(
        _stripMarkdownInline(row.isNotEmpty ? row.first : ''),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < headers.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _RowDetailField(
                label: _stripMarkdownInline(headers[i]),
                markdown: row[i],
                emphasized: i == focusedColumn,
                accentColor: colors.primary,
                markdownStyle: markdownStyle,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('關閉'),
        ),
      ],
    );
  }
}

class _RowDetailField extends StatelessWidget {
  const _RowDetailField({
    required this.label,
    required this.markdown,
    required this.emphasized,
    required this.accentColor,
    required this.markdownStyle,
  });

  final String label;
  final String markdown;

  /// 是否強調這欄（使用者點的那個 cell）
  final bool emphasized;
  final Color accentColor;
  final MarkdownStyleSheet markdownStyle;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: emphasized
              ? accentColor
              : Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: emphasized ? FontWeight.bold : FontWeight.w500,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 4),
        // dialog 內用 MarkdownBody 完整渲染，cell 被 strip 掉的粗體/連結
        // 在這裡都會補回，這就是「快覽 cell + 詳看 dialog」分工的價值
        MarkdownBody(
          data: markdown.isEmpty ? '—' : markdown,
          styleSheet: markdownStyle,
          selectable: true,
        ),
      ],
    );
  }
}

// ---------- Inline markdown stripper ----------

// 把行內 markdown 樣式去除，留下純文字給 cell 顯示
// 為什麼用 regex 而非 markdown package 的 inline parser：
// 這幾個情境覆蓋目前所有筆記用法，工作量極低；引入 inline parser 邊際效益
// 不高。未來若 cell 真有複雜 inline markdown 再升級
String _stripMarkdownInline(String input) {
  var output = input;
  // **bold** → bold
  output = output.replaceAllMapped(
    RegExp(r'\*\*([^*]+)\*\*'),
    (m) => m.group(1)!,
  );
  // *italic* → italic（避開連續星號）
  output = output.replaceAllMapped(
    RegExp(r'(?<!\*)\*([^*]+)\*(?!\*)'),
    (m) => m.group(1)!,
  );
  // [link text](url) → link text
  output = output.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\([^)]+\)'),
    (m) => m.group(1)!,
  );
  // `code` → code
  output = output.replaceAll('`', '');
  return output;
}
