// home_view_model.dart
//
// HomePage 的 ViewModel：負責載入「對照檔」並 parse 成日期區段。
//
// 為什麼從 StatefulWidget + FutureBuilder 改成 ChangeNotifier：
// - View 不該知道「怎麼載」「失敗怎麼處理」，只該宣告「我要呈現的狀態」
// - 有可注入的 loader / parser，未來才寫得出 unit test（直接 new 一個 VM 餵假 service）
// - Phase 3 的全文搜尋會需要把載入結果跨頁共享，預先抽 VM 才有上升 scope 的空間
//
// 為什麼用建構式注入而不是內部 new：
// 對應 iOS DI 慣例——View 不該決定 service 怎麼建，由外層 Provider 樹注入，
// 測試時直接 new HomeViewModel(loader: FakeLoader(), ...) 就能跑

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../models/note_source.dart';
import '../services/markdown_loader.dart';
import '../services/markdown_section_parser.dart';

/// 載入狀態機。
///
/// 為什麼用 enum 而不是分開的 `bool isLoading / hasError`：
/// 多個獨立 bool 容易出現不合法組合（例如同時 loading=true、hasData=true），
/// enum 保證任一時刻只會在一個狀態，View 用 switch 也能讓編譯器檢查窮舉。
enum HomeLoadState { idle, loading, success, error }

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required MarkdownLoader loader,
    required MarkdownSectionParser parser,
    NoteSource? source,
  })  : _loader = loader,
        _parser = parser,
        // 預設讀對照檔；保留可注入是為了未來「同一個 VM 拿來顯示分析師檔」的可能
        _source = source ?? NoteSource.comparison;

  final MarkdownLoader _loader;
  final MarkdownSectionParser _parser;
  final NoteSource _source;

  HomeLoadState _state = HomeLoadState.idle;
  List<MarkdownSection> _sections = const [];
  Object? _error;

  HomeLoadState get state => _state;
  List<MarkdownSection> get sections => _sections;
  Object? get error => _error;

  /// 觸發載入（首次顯示 / retry 都呼叫這個）。
  ///
  /// 回傳 Future 是給測試方便 await；View 端只需訂閱 state 變化，不必 await。
  Future<void> load() async {
    // 防止重複觸發：若已經在載入中，直接忽略
    // （例如 widget rebuild 重新呼叫 load() 時不該重啟一次請求）
    if (_state == HomeLoadState.loading) return;

    _state = HomeLoadState.loading;
    // 進新一輪載入時清掉舊錯誤，避免 retry 成功後 UI 仍殘留錯誤訊息
    _error = null;
    notifyListeners();

    try {
      final markdown = await _loader.load(_source.assetPath);
      _sections = _parser.parse(markdown);
      _state = HomeLoadState.success;
    } catch (error) {
      _error = error;
      _state = HomeLoadState.error;
    }
    notifyListeners();
  }
}
