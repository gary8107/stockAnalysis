// home_view_model_test.dart
//
// HomeViewModel 單元測試。
//
// 為什麼用 test() 而不是 testWidgets()：
// VM 是純 Dart 邏輯，不依賴 widget tree；不用 pumpWidget 啟動框架，
// 測試跑得更快、訊號也更聚焦在 VM 狀態機本身。
//
// 為什麼不 mock parser、只 mock loader：
// MarkdownSectionParser.parse() 是純函式，直接用真的就好；
// 「VM + parser」一起測也順便驗證日期區段切割沒因為 VM 改動跑掉。

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_analysis/services/markdown_loader.dart';
import 'package:stock_analysis/services/markdown_section_parser.dart';
import 'package:stock_analysis/viewmodels/home_view_model.dart';

// 假 loader：繼承真實 MarkdownLoader 並 override load()。
// 用 plain Dart 取代 mocktail/mockito，依賴更少、意圖也更明顯
class _FakeLoader extends MarkdownLoader {
  String markdown = '';
  Object? error;
  int loadCalls = 0;

  @override
  Future<String> load(String assetPath) async {
    loadCalls++;
    if (error != null) throw error!;
    return markdown;
  }
}

const _sampleMarkdown = '''
## 2026-05-15（對照日期）

第一天內容

## 2026-05-14（對照日期）

第二天內容
''';

void main() {
  group('HomeViewModel', () {
    test('初始狀態：idle、sections 空、error null', () {
      final viewModel = HomeViewModel(
        loader: _FakeLoader(),
        parser: MarkdownSectionParser(),
      );

      expect(viewModel.state, HomeLoadState.idle);
      expect(viewModel.sections, isEmpty);
      expect(viewModel.error, isNull);
    });

    test('load 成功：state 走 loading → success，sections 被 parse 填入', () async {
      final stateLog = <HomeLoadState>[];
      final viewModel = HomeViewModel(
        loader: _FakeLoader()..markdown = _sampleMarkdown,
        parser: MarkdownSectionParser(),
      );
      viewModel.addListener(() => stateLog.add(viewModel.state));

      await viewModel.load();

      expect(stateLog, [HomeLoadState.loading, HomeLoadState.success]);
      expect(viewModel.sections, hasLength(2));
      expect(viewModel.sections.first.date, '2026-05-15');
      expect(viewModel.error, isNull);
    });

    test('load 失敗：state 走 loading → error，error 有值、sections 不變', () async {
      final stateLog = <HomeLoadState>[];
      final viewModel = HomeViewModel(
        loader: _FakeLoader()..error = 'boom',
        parser: MarkdownSectionParser(),
      );
      viewModel.addListener(() => stateLog.add(viewModel.state));

      await viewModel.load();

      expect(stateLog, [HomeLoadState.loading, HomeLoadState.error]);
      expect(viewModel.error, 'boom');
      expect(viewModel.sections, isEmpty);
    });

    test('retry：新一輪 load 進入 loading 當下就清掉舊 error', () async {
      final loader = _FakeLoader()..error = 'boom';
      final viewModel = HomeViewModel(
        loader: loader,
        parser: MarkdownSectionParser(),
      );
      await viewModel.load();
      expect(viewModel.error, 'boom'); // 第一輪確認失敗

      // 修好 loader，準備第二輪
      loader.error = null;
      loader.markdown = _sampleMarkdown;

      // 用 listener 捕捉「loading 階段當下」的 error 值
      // 預期：進入 loading 時 _error 已被清成 null
      Object? errorAtLoadingMoment;
      var loadingObserved = false;
      viewModel.addListener(() {
        if (viewModel.state == HomeLoadState.loading && !loadingObserved) {
          loadingObserved = true;
          errorAtLoadingMoment = viewModel.error;
        }
      });

      await viewModel.load();

      expect(loadingObserved, isTrue);
      expect(errorAtLoadingMoment, isNull);
      expect(viewModel.state, HomeLoadState.success);
      expect(viewModel.error, isNull);
    });

    test('防重入：loading 中重複呼叫 load，loader 只被呼叫一次', () async {
      final loader = _FakeLoader()..markdown = _sampleMarkdown;
      final viewModel = HomeViewModel(
        loader: loader,
        parser: MarkdownSectionParser(),
      );

      // 不 await 第一次，立刻發第二次；此時 _state 已是 loading，第二次應立即 return
      final firstLoad = viewModel.load();
      final secondLoad = viewModel.load();
      await Future.wait([firstLoad, secondLoad]);

      expect(loader.loadCalls, 1);
      expect(viewModel.state, HomeLoadState.success);
    });
  });
}
