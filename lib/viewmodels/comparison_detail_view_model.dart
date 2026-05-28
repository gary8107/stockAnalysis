// comparison_detail_view_model.dart
//
// ComparisonDetailPage 的 ViewModel。
//
// 角色：拿 NotesApiService.load() 取整份 NotesIndex 後，從 comparisons 過濾
// 出指定日期的 entry。結構與 HomeViewModel / NoteViewModel 對齊（四態 enum、
// Future cache 由 service 處理、_state 變化推 notifyListeners）。
//
// 為什麼用單獨一支 VM 而非直接在頁面 FutureBuilder：
// 1. 跟既有 VM layer 一致，view 端不必同時面對 FutureBuilder 與 Provider
//    兩種 state 表達方式
// 2. 將來要擴充「對照當日 → 跳到某位分析師當日個別筆記」這類延伸功能時，
//    VM 已經能存到該 entry，不必再從 view 反查 NotesIndex
// 3. 測試友善：fake NotesApiService 注入後可以單獨對 VM 做單元測試
//
// 為什麼 service 仍然走 load() 而非新增 loadByDate：
// NotesApiService 內建 Future cache（同份 in-flight request 共享），
// HomeViewModel 已 load 過後，這支 VM 再 load 不會重打網路，只會 await
// 已 resolve 的 Future 後做一次 list 過濾——成本可忽略。

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../models/note_entry.dart';
import '../services/notes_api_service.dart';

enum ComparisonDetailLoadState { idle, loading, success, error }

class ComparisonDetailViewModel extends ChangeNotifier {
  ComparisonDetailViewModel({
    required NotesApiService api,
    required this.date,
  }) : _api = api;

  final NotesApiService _api;

  /// 要顯示哪一天的對照——ISO 字串，例如 "2026-05-22"。
  /// 路由 path param 帶進來、view 從 viewModel.date 讀回去當標題用
  final String date;

  ComparisonDetailLoadState _state = ComparisonDetailLoadState.idle;
  NoteEntry? _entry;
  Object? _error;

  ComparisonDetailLoadState get state => _state;

  /// success 後若仍為 null，表示該日期不在 NotesIndex.comparisons——
  /// 通常代表使用者用了舊書籤、或直接輸入了不存在日期的 URL；
  /// view 端需要把這個 case 跟「載入失敗」區分（前者不該觸發 retry）
  NoteEntry? get entry => _entry;

  Object? get error => _error;

  Future<void> load() async {
    // 防止 widget rebuild 期間重複觸發 fetch
    if (_state == ComparisonDetailLoadState.loading) return;

    _state = ComparisonDetailLoadState.loading;
    _error = null;
    notifyListeners();

    try {
      final index = await _api.load();
      // 用 for-loop 而非 firstWhere——後者沒有 nullable 版本，要嘛包 try/catch
      // StateError，要嘛走 .where().isEmpty 後再 .first，都比 for-loop 繞。
      // collection 預期不大（每日一筆對照），線性掃成本可忽略
      NoteEntry? matched;
      for (final candidate in index.comparisons) {
        if (candidate.date == date) {
          matched = candidate;
          break;
        }
      }
      _entry = matched;
      _state = ComparisonDetailLoadState.success;
    } catch (error) {
      _error = error;
      _state = ComparisonDetailLoadState.error;
    }
    notifyListeners();
  }
}
