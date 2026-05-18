// notes_index.dart
//
// 整份 notes.json 的 Dart 對映。
//
// JSON 結構（Phase 2.5 schema v1.0）：
// ```
// {
//   "version": "1.0",
//   "generated_at": "2026-05-18T00:00:00Z",
//   "analysts": [Analyst, ...],
//   "comparisons": [NoteEntry, ...],   // 跨分析師對照
//   "notes": [NoteEntry with analyst_key, ...]  // 個別分析師
// }
// ```

import 'analyst.dart';
import 'note_entry.dart';

class NotesIndex {
  const NotesIndex({
    required this.version,
    required this.generatedAt,
    required this.analysts,
    required this.comparisons,
    required this.notes,
  });

  /// Schema 版本，未來 breaking change 時用來判斷相容性
  final String version;

  /// JSON 產生時間（build script 跑的時間點），UI 可顯示「最後更新時間」
  final DateTime generatedAt;

  final List<Analyst> analysts;

  /// 跨分析師對照 entries（analystKey 都是 null）
  final List<NoteEntry> comparisons;

  /// 個別分析師 entries（analystKey 都不是 null）
  final List<NoteEntry> notes;

  factory NotesIndex.fromJson(Map<String, dynamic> json) => NotesIndex(
        version: json['version'] as String,
        generatedAt: DateTime.parse(json['generated_at'] as String),
        analysts: (json['analysts'] as List)
            .map((a) => Analyst.fromJson(a as Map<String, dynamic>))
            .toList(growable: false),
        comparisons: (json['comparisons'] as List)
            .map((c) => NoteEntry.fromJson(c as Map<String, dynamic>))
            .toList(growable: false),
        notes: (json['notes'] as List)
            .map((n) => NoteEntry.fromJson(n as Map<String, dynamic>))
            .toList(growable: false),
      );

  Map<String, dynamic> toJson() => {
        'version': version,
        'generated_at': generatedAt.toUtc().toIso8601String(),
        'analysts': analysts.map((a) => a.toJson()).toList(),
        'comparisons': comparisons.map((c) => c.toJson()).toList(),
        'notes': notes.map((n) => n.toJson()).toList(),
      };

  /// 取特定分析師的所有日期 entry。
  /// 用 key 而非 name 查詢——name 可能變動但 key 穩定（見 Analyst doc）。
  List<NoteEntry> notesByAnalyst(String analystKey) =>
      notes.where((n) => n.analystKey == analystKey).toList(growable: false);

  Analyst? analystByKey(String key) {
    for (final a in analysts) {
      if (a.key == key) return a;
    }
    return null;
  }
}
