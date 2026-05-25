// build_notes_json.dart
//
// Phase 2.5 build step：把 assets/notes/*.md 轉成 web/api/notes.json。
//
// 設計取捨：
// - Standalone dart script（dart:io），不能在 web 上跑——所以放 tool/ 而非 lib/
// - H2 日期 region 切割 regex 從原 lib/services/markdown_section_parser.dart
//   遷移過來（該檔已在 Phase 2.5 step 7 移除）
// - 表格識別走簡單 line-based scanner：遇到 `|xxx|` + 下一行 `|---|` 就抓 table，
//   不依賴 package:markdown 的完整 AST——降低 build 依賴、邊角情境可控
// - 表格之外的內容全歸 MarkdownBlock（一坨字串），view 端用 flutter_markdown 渲染
//
// 用法：
//   dart run tool/build_notes_json.dart            # 從 repo 根目錄跑
//
// 輸出：web/api/notes.json（提交進 git；flutter build web 會自動帶上）

import 'dart:convert';
import 'dart:io';

import 'package:stock_analysis/models/analyst.dart';
import 'package:stock_analysis/models/note_block.dart';
import 'package:stock_analysis/models/note_entry.dart';
import 'package:stock_analysis/models/notes_index.dart';

// 分析師清單——這份是 Phase 2.5 後 analyst metadata 的 single source of
// truth（原 lib/models/note_source.dart 在 step 7 移除）。新增分析師時
// 同步更新 _analystFiles 對映即可
const _analysts = <Analyst>[
  Analyst(
    key: 'ruan-huici',
    name: '阮蕙慈',
    description: '大華國際投顧 · 金融阮實力',
    thumbnail: 'assets/thumbnails/ruan-huici.jpg',
  ),
  Analyst(
    key: 'li-shufang',
    name: '李蜀芳',
    description: '永誠國際投顧 · 股市全芳位',
    thumbnail: 'assets/thumbnails/li-shufang.jpg',
  ),
  Analyst(
    key: 'chen-kunjen',
    name: '陳昆仁(大仁哥)',
    description: '摩爾證券投顧 · 仁者無敵',
    thumbnail: 'assets/thumbnails/chen-kunjen.jpg',
  ),
  Analyst(
    key: 'cai-zhenghua',
    name: '蔡正華',
    description: '大來國際投顧 · 理財金錢道',
    thumbnail: 'assets/thumbnails/cai-zhenghua.jpg',
  ),
];

// 檔案路徑 → analyst key 對映
const _analystFiles = <String, String>{
  'assets/notes/阮蕙慈分析.md': 'ruan-huici',
  'assets/notes/李蜀芳分析.md': 'li-shufang',
  'assets/notes/陳昆仁分析.md': 'chen-kunjen',
  'assets/notes/蔡正華分析.md': 'cai-zhenghua',
};

const _comparisonFile = 'assets/notes/分析師對照重點.md';
const _outputPath = 'web/api/notes.json';

void main(List<String> args) {
  final stopwatch = Stopwatch()..start();

  final comparisons = _parseFile(_comparisonFile, analystKey: null);
  final notes = <NoteEntry>[];
  for (final entry in _analystFiles.entries) {
    notes.addAll(_parseFile(entry.key, analystKey: entry.value));
  }

  final index = NotesIndex(
    version: '1.0',
    generatedAt: DateTime.now().toUtc(),
    analysts: _analysts,
    comparisons: comparisons,
    notes: notes,
  );

  final output = File(_outputPath);
  output.parent.createSync(recursive: true);
  // 用 indented JSON 讓 git diff 看得到變化（不會整檔擠成一行）
  final encoder = const JsonEncoder.withIndent('  ');
  output.writeAsStringSync(encoder.convert(index.toJson()));

  stopwatch.stop();
  stdout.writeln(
    'Wrote ${output.path} '
    '(${_humanSize(output.lengthSync())}) '
    '— ${comparisons.length} comparison entries, ${notes.length} analyst entries '
    'in ${stopwatch.elapsedMilliseconds}ms',
  );
}

List<NoteEntry> _parseFile(String path, {required String? analystKey}) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('warning: $path not found, skipping');
    return const [];
  }
  final markdown = file.readAsStringSync();
  final regions = _splitH2DateRegions(markdown);
  return regions
      .map(
        (region) => NoteEntry(
          date: region.date,
          note: region.note,
          blocks: _parseBlocks(region.content),
          analystKey: analystKey,
        ),
      )
      .toList(growable: false);
}

// ---------- H2 日期 region 切割 ----------

class _Region {
  const _Region({
    required this.date,
    required this.note,
    required this.content,
  });
  final String date;
  final String? note;
  final String content; // H2 標題行的下一行起、到下個 H2 之前；不含 H2 本身
}

// 偵測 `## YYYY-MM-DD` 開頭的 H2 標題，並抓出可選的「（...）」副標。
// 兼容半形 () 與全形 （）；group(1)=日期、group(2)=副標
final _h2DateRegex = RegExp(
  r'^## (\d{4}-\d{2}-\d{2})(?:\s*[（(]([^）)]+)[）)])?',
  multiLine: true,
);

List<_Region> _splitH2DateRegions(String markdown) {
  final matches = _h2DateRegex.allMatches(markdown).toList();
  if (matches.isEmpty) return const [];
  final regions = <_Region>[];
  for (var i = 0; i < matches.length; i++) {
    final match = matches[i];
    final date = match.group(1)!;
    final rawNote = match.group(2)?.trim();
    final note = (rawNote != null && rawNote.isNotEmpty) ? rawNote : null;

    // content 從 H2 標題行的下一行開始（不含 H2 本身——日期/副標已抽出）
    final firstNewline = markdown.indexOf('\n', match.start);
    final contentStart =
        firstNewline == -1 ? markdown.length : firstNewline + 1;
    final end =
        (i + 1 < matches.length) ? matches[i + 1].start : markdown.length;
    final content = markdown.substring(contentStart, end).trim();

    regions.add(_Region(date: date, note: note, content: content));
  }
  return regions;
}

// ---------- Block 切割（markdown / table） ----------

List<NoteBlock> _parseBlocks(String content) {
  final lines = content.split('\n');
  final blocks = <NoteBlock>[];
  final mdBuffer = <String>[];

  void flushMarkdown() {
    if (mdBuffer.isEmpty) return;
    final text = mdBuffer.join('\n').trim();
    mdBuffer.clear();
    if (text.isEmpty) return;
    blocks.add(MarkdownBlock(content: text));
  }

  var i = 0;
  while (i < lines.length) {
    final line = lines[i];
    // 偵測 table 起點：當前行像 header row、下一行是 separator
    if (i + 1 < lines.length &&
        _isTableHeaderRow(line) &&
        _isTableSeparatorRow(lines[i + 1])) {
      flushMarkdown();
      final headers = _splitCells(line);
      final rows = <List<String>>[];
      i += 2; // 跳過 header + separator 兩行
      while (i < lines.length && _isTableDataRow(lines[i])) {
        rows.add(_splitCells(lines[i]));
        i++;
      }
      // 補齊或截斷 cells 到 headers.length，避免後續 view 端 index out of bounds
      final normalized = rows
          .map((row) {
            if (row.length == headers.length) return row;
            if (row.length < headers.length) {
              return [
                ...row,
                ...List.filled(headers.length - row.length, ''),
              ];
            }
            return row.sublist(0, headers.length);
          })
          .toList(growable: false);
      blocks.add(TableBlock(headers: headers, rows: normalized));
      // 不要 i++，因為 while 已經停在「非 data row」那行
    } else {
      mdBuffer.add(line);
      i++;
    }
  }
  flushMarkdown();
  return blocks;
}

// Header row：以 | 開頭、結尾，中間至少有一個非 separator 字元
bool _isTableHeaderRow(String line) {
  final trimmed = line.trim();
  if (!trimmed.startsWith('|') || !trimmed.endsWith('|')) return false;
  if (trimmed.length < 3) return false;
  // 不能本身就是 separator（避免誤認 separator 為 header）
  return !_isTableSeparatorRow(line);
}

// Separator row：去掉 | 後只剩 - : 空白
bool _isTableSeparatorRow(String line) {
  final trimmed = line.trim();
  if (!trimmed.startsWith('|')) return false;
  final inner = trimmed.replaceAll('|', '');
  if (inner.isEmpty) return false;
  return RegExp(r'^[\s:\-]+$').hasMatch(inner);
}

// Data row：以 | 開頭即可（separator 在前面被 while loop 跳過了）
bool _isTableDataRow(String line) {
  final trimmed = line.trim();
  return trimmed.startsWith('|');
}

// 拆 cell：去頭尾的 | 後按 | split，再 trim 每個 cell
// 注意：目前筆記內容沒有 escaped \| 的需要，後續若出現再加處理
List<String> _splitCells(String line) {
  var trimmed = line.trim();
  if (trimmed.startsWith('|')) trimmed = trimmed.substring(1);
  if (trimmed.endsWith('|')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed
      .split('|')
      .map((cell) => cell.trim())
      .toList(growable: false);
}

// ---------- Helpers ----------

String _humanSize(int bytes) {
  if (bytes < 1024) return '${bytes}B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
}
