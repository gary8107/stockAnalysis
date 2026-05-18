// home_view_model.dart
//
// HomePage 的 ViewModel。Phase 2.5 起依賴 NotesApiService（取代 Phase 2 的
// MarkdownLoader + MarkdownSectionParser 組合）。
//
// 暴露給 View 的兩種資料：
// - comparisons：跨分析師對照 entries，給日期 TabBar + 主內容用
// - analysts：分析師清單，給上方分析師卡片用
//
// 為什麼一個 VM 暴露兩種資料而非各自獨立 VM：
// HomePage 同一畫面同時需要這兩種資料，一次 load() 取整份 NotesIndex 後
// 拆出來顯示，比兩個 VM 各管自己的 state 簡單；NotesApiService 內建 Future
// cache，將來 NoteViewModel 也呼叫 load() 也不會重複 fetch。

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../models/analyst.dart';
import '../models/note_entry.dart';
import '../services/notes_api_service.dart';

enum HomeLoadState { idle, loading, success, error }

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({required NotesApiService api}) : _api = api;

  final NotesApiService _api;

  HomeLoadState _state = HomeLoadState.idle;
  List<NoteEntry> _comparisons = const [];
  List<Analyst> _analysts = const [];
  Object? _error;

  HomeLoadState get state => _state;
  List<NoteEntry> get comparisons => _comparisons;
  List<Analyst> get analysts => _analysts;
  Object? get error => _error;

  /// 觸發載入（首次顯示 / retry 都呼叫這個）。
  /// 回傳 Future 是給測試方便 await；View 端只需訂閱 state 變化，不必 await。
  Future<void> load() async {
    // 防止重複觸發（例如 widget rebuild 又呼叫一次 load）
    if (_state == HomeLoadState.loading) return;

    _state = HomeLoadState.loading;
    // 進新一輪載入時清掉舊錯誤，避免 retry 成功後 UI 仍殘留錯誤訊息
    _error = null;
    notifyListeners();

    try {
      final index = await _api.load();
      _comparisons = index.comparisons;
      _analysts = index.analysts;
      _state = HomeLoadState.success;
    } catch (error) {
      _error = error;
      _state = HomeLoadState.error;
    }
    notifyListeners();
  }
}
