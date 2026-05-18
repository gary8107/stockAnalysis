// note_entry.dart
//
// 一個日期 entry——「某天的筆記內容」。
//
// 對照檔和個別分析師檔結構幾乎相同（日期、副標、blocks），唯一差別是
// 「對照檔沒有 analyst_key」。為了避免 view 端要做兩套類似的渲染分支，
// 統一成單一 NoteEntry class，用 analystKey == null 表示對照 entry。
//
// 設計取捨：
// - 也考慮過 `sealed class NoteEntry` + `ComparisonEntry`/`AnalystEntry`
//   兩個 subtype，但 view 端 switch 處理兩個都一樣只是 print，過度設計
// - nullable analystKey 把「這是不是對照」這個資訊內嵌在資料本身，
//   配合 NotesIndex.comparisons / notes 兩個 collection 各自過濾，意圖夠清楚

import 'note_block.dart';

class NoteEntry {
  const NoteEntry({
    required this.date,
    required this.note,
    required this.blocks,
    this.analystKey,
  });

  /// ISO 日期字串，例如 "2026-05-14"
  final String date;

  /// H2 標題括號內的副標（例如 "對照日期"、"影片日期"、"盤前 · 追高警告場"），
  /// 沒括號則為 null
  final String? note;

  /// 該日內容拆段後的 blocks
  final List<NoteBlock> blocks;

  /// 對照 entry 為 null，個別分析師 entry 為對應 Analyst.key
  final String? analystKey;

  bool get isComparison => analystKey == null;

  factory NoteEntry.fromJson(Map<String, dynamic> json) => NoteEntry(
        date: json['date'] as String,
        note: json['note'] as String?,
        blocks: (json['blocks'] as List)
            .map((block) => NoteBlock.fromJson(block as Map<String, dynamic>))
            .toList(growable: false),
        analystKey: json['analyst_key'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        if (note != null) 'note': note,
        'blocks': blocks.map((block) => block.toJson()).toList(),
        if (analystKey != null) 'analyst_key': analystKey,
      };

  // 「影片日期 / 對照日期 / 筆記日期」這類泛用副標對使用者不額外有意義，
  // UI 直接忽略；保留「盤前/盤後/特殊場次」這類有區分價值的副標。
  // 邏輯保留自原 MarkdownSection.displayNote，避免 view 端各自重寫
  static const _genericNotes = {'影片日期', '對照日期', '筆記日期'};

  String? get displayNote {
    final value = note;
    if (value == null) return null;
    if (_genericNotes.contains(value)) return null;
    return value;
  }
}
