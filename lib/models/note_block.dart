// note_block.dart
//
// 筆記中的一段內容。
//
// 為什麼用 sealed class：
// view 端 switch 處理 block 時，編譯器會強制窮舉所有 subtype，
// 將來新增 type 忘記處理會直接編譯不過、不會 silently 漏渲染。
//
// 為什麼起手只有 2 種 type 而非 heading/paragraph/list/blockquote 各自獨立：
// 表格之外的內容 flutter_markdown 渲染本來就 OK，這次拆 API 的核心動機
// 是「表格 UI 自訂渲染」；其他內容沒抱怨，全部當 markdown 字串塞進
// MarkdownBlock 最簡單。未來真要拆細（例如想做「按 heading 折疊」）再加 type。

sealed class NoteBlock {
  const NoteBlock();

  factory NoteBlock.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    return switch (type) {
      'markdown' => MarkdownBlock(content: json['content'] as String),
      'table' => TableBlock(
          headers: (json['headers'] as List).cast<String>(),
          rows: (json['rows'] as List)
              .map((row) => (row as List).cast<String>())
              .toList(growable: false),
        ),
      _ => throw FormatException('Unknown block type: $type'),
    };
  }

  Map<String, dynamic> toJson();
}

/// 一坨 markdown 字串（可能含 heading / paragraph / list / blockquote / 行內粗體連結等）。
/// View 端用 flutter_markdown 渲染，套用既有 markdown style sheet。
class MarkdownBlock extends NoteBlock {
  const MarkdownBlock({required this.content});

  final String content;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'markdown',
        'content': content,
      };
}

/// 結構化表格。
///
/// cell 內容仍保留 inline markdown（例如 "**41,751**"）；view 端用
/// MarkdownBody(shrinkWrap: true) 渲染單 cell，這樣粗體 / 連結 / 斜體
/// 都能保留，又能控制 cell 寬度與 tap 行為（解決原本 flutter_markdown
/// 整個 table 包水平 scroll、滑到邊邊誤觸 TabBar 切日期的 UX 問題）。
class TableBlock extends NoteBlock {
  const TableBlock({
    required this.headers,
    required this.rows,
  });

  /// 欄位標頭（第一列），cell 數 = headers.length
  final List<String> headers;

  /// 資料列，每列 cell 數應等於 headers.length（parser 會補齊或截斷）
  final List<List<String>> rows;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'table',
        'headers': headers,
        'rows': rows,
      };
}
