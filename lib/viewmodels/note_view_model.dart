// note_view_model.dart
//
// NotePage 的 ViewModel。Phase 2.5 起依賴 NotesApiService。
//
// 接收 analystKey，從 NotesIndex.notes 過濾出該分析師的 entries，
// 並從 NotesIndex.analysts 查 metadata（name / description / thumbnail）。
//
// 跟 Phase 2 版本的差別：
// - 不再持有 NoteSource（已淘汰）；改用 analystKey 字串對映 Analyst
// - 不再有 rawMarkdown 與 fallback view 概念：新 schema 把內容切成 blocks，
//   沒有「整檔 markdown 字串」這個概念。blocks 為空時 view 顯示「沒資料」即可

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../models/analyst.dart';
import '../models/note_entry.dart';
import '../services/notes_api_service.dart';

enum NoteLoadState { idle, loading, success, error }

class NoteViewModel extends ChangeNotifier {
  NoteViewModel({
    required NotesApiService api,
    required this.analystKey,
  }) : _api = api;

  final NotesApiService _api;

  /// 此頁顯示哪位分析師——對映 Analyst.key
  final String analystKey;

  NoteLoadState _state = NoteLoadState.idle;
  Analyst? _analyst;
  List<NoteEntry> _entries = const [];
  Object? _error;

  NoteLoadState get state => _state;

  /// Banner 顯示用的分析師 metadata。
  /// success 後若仍為 null，表示 analystKey 在 NotesIndex.analysts 找不到對映
  /// （錯誤 URL 或筆記資料尚未同步）——view 端要處理這個 case
  Analyst? get analyst => _analyst;

  List<NoteEntry> get entries => _entries;
  Object? get error => _error;

  Future<void> load() async {
    if (_state == NoteLoadState.loading) return;

    _state = NoteLoadState.loading;
    _error = null;
    notifyListeners();

    try {
      final index = await _api.load();
      _analyst = index.analystByKey(analystKey);
      _entries = index.notesByAnalyst(analystKey);
      _state = NoteLoadState.success;
    } catch (error) {
      _error = error;
      _state = NoteLoadState.error;
    }
    notifyListeners();
  }
}
