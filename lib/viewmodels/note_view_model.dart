// note_view_model.dart
//
// NotePage 的 ViewModel：載入指定的 NoteSource 並 parse 成日期區段。
//
// 跟 HomeViewModel 的差別：
// - source 是 required（每個 NotePage 顯示不同的分析師檔，沒有預設值）
// - 額外保留 rawMarkdown，給「沒有日期區段時的整檔 fallback view」使用，
//   避免為了 fallback 再呼叫 loader 一次
//
// 為什麼 NoteLoadState 跟 HomeLoadState 看起來一樣但仍各自獨立宣告：
// 這是「ViewModel 自有的狀態類型」而非通用工具，獨立宣告能讓編譯器幫忙
// 標示「這個狀態是給哪個 VM 用」，避免將來兩個 VM 的狀態語義分歧時誤用；
// 若之後第三個 VM 又出現同樣四態才考慮抽 common AsyncLoadState（YAGNI）。

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../models/note_source.dart';
import '../services/markdown_loader.dart';
import '../services/markdown_section_parser.dart';

enum NoteLoadState { idle, loading, success, error }

class NoteViewModel extends ChangeNotifier {
  NoteViewModel({
    required MarkdownLoader loader,
    required MarkdownSectionParser parser,
    required this.source,
  })  : _loader = loader,
        _parser = parser;

  final MarkdownLoader _loader;
  final MarkdownSectionParser _parser;

  /// 此頁要顯示的筆記來源——同時用來決定載入路徑（assetPath）
  /// 與 Banner 顯示資訊（name / description / thumbnail）
  final NoteSource source;

  NoteLoadState _state = NoteLoadState.idle;
  String _rawMarkdown = '';
  List<MarkdownSection> _sections = const [];
  Object? _error;

  NoteLoadState get state => _state;

  /// 原始 markdown 文字。
  /// 暴露這個是給 fallback view 用——當這份檔不符合 `## YYYY-MM-DD` 日期區段
  /// 格式時（_sections 為空），View 退回整檔渲染，這時直接拿這份原文，不再
  /// 觸發第二次 load
  String get rawMarkdown => _rawMarkdown;

  List<MarkdownSection> get sections => _sections;
  Object? get error => _error;

  /// 觸發載入（首次顯示 / retry 都呼叫這個）。
  Future<void> load() async {
    // 防止重複觸發（例如 widget rebuild 又呼叫一次 load）
    if (_state == NoteLoadState.loading) return;

    _state = NoteLoadState.loading;
    // 進新一輪載入時清掉舊錯誤，避免 retry 成功後 UI 仍殘留錯誤訊息
    _error = null;
    notifyListeners();

    try {
      final markdown = await _loader.load(source.assetPath);
      _rawMarkdown = markdown;
      _sections = _parser.parse(markdown);
      _state = NoteLoadState.success;
    } catch (error) {
      _error = error;
      _state = NoteLoadState.error;
    }
    notifyListeners();
  }
}
