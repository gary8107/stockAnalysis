// note_view_model_test.dart
//
// NoteViewModel 單元測試。
// 結構對齊 HomeViewModel 測試，多測 rawMarkdown 與 source.assetPath 路由。
//
// 用真實 NoteSource.analysts.first 而不是另建 fake source：
// NoteSource 是 value object 沒副作用，用真的更貼近實際使用情境，
// 也順便驗證 const 來源清單不會壞。

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_analysis/models/note_source.dart';
import 'package:stock_analysis/services/markdown_loader.dart';
import 'package:stock_analysis/services/markdown_section_parser.dart';
import 'package:stock_analysis/viewmodels/note_view_model.dart';

// 假 loader：跟 home_view_model_test 相同 pattern。
// 各檔自己持一份是為了讓測試檔自包含、好讀；若未來再多兩三個 VM 都需要
// 同款 fake，再考慮抽 test/helpers/fake_loader.dart 共用
class _FakeLoader extends MarkdownLoader {
  String markdown = '';
  Object? error;
  int loadCalls = 0;
  final List<String> loadedPaths = [];

  @override
  Future<String> load(String assetPath) async {
    loadCalls++;
    loadedPaths.add(assetPath);
    if (error != null) throw error!;
    return markdown;
  }
}

const _sampleMarkdown = '''
## 2026-05-15（影片日期）

第一天

## 2026-05-14（影片日期）

第二天
''';

final _testSource = NoteSource.analysts.first;

void main() {
  group('NoteViewModel', () {
    test('初始狀態：idle、rawMarkdown 空、sections 空、error null、source 等於建構參數', () {
      final viewModel = NoteViewModel(
        loader: _FakeLoader(),
        parser: MarkdownSectionParser(),
        source: _testSource,
      );

      expect(viewModel.state, NoteLoadState.idle);
      expect(viewModel.rawMarkdown, '');
      expect(viewModel.sections, isEmpty);
      expect(viewModel.error, isNull);
      expect(viewModel.source, same(_testSource));
    });

    test('load 成功：rawMarkdown 與 sections 一起填入', () async {
      final stateLog = <NoteLoadState>[];
      final viewModel = NoteViewModel(
        loader: _FakeLoader()..markdown = _sampleMarkdown,
        parser: MarkdownSectionParser(),
        source: _testSource,
      );
      viewModel.addListener(() => stateLog.add(viewModel.state));

      await viewModel.load();

      expect(stateLog, [NoteLoadState.loading, NoteLoadState.success]);
      expect(viewModel.rawMarkdown, _sampleMarkdown);
      expect(viewModel.sections, hasLength(2));
      expect(viewModel.sections.first.date, '2026-05-15');
      expect(viewModel.error, isNull);
    });

    test('load 用 source.assetPath 載入，不是別的路徑', () async {
      final loader = _FakeLoader()..markdown = _sampleMarkdown;
      final viewModel = NoteViewModel(
        loader: loader,
        parser: MarkdownSectionParser(),
        source: _testSource,
      );

      await viewModel.load();

      expect(loader.loadedPaths, [_testSource.assetPath]);
    });

    test('load 失敗：state 變 error，rawMarkdown 維持空字串', () async {
      final viewModel = NoteViewModel(
        loader: _FakeLoader()..error = 'boom',
        parser: MarkdownSectionParser(),
        source: _testSource,
      );

      await viewModel.load();

      expect(viewModel.state, NoteLoadState.error);
      expect(viewModel.error, 'boom');
      // rawMarkdown 不該被覆寫成壞資料
      expect(viewModel.rawMarkdown, '');
    });

    test('retry：新一輪 load 進入 loading 當下就清掉舊 error', () async {
      final loader = _FakeLoader()..error = 'boom';
      final viewModel = NoteViewModel(
        loader: loader,
        parser: MarkdownSectionParser(),
        source: _testSource,
      );
      await viewModel.load();
      expect(viewModel.error, 'boom');

      loader.error = null;
      loader.markdown = _sampleMarkdown;

      Object? errorAtLoadingMoment;
      var loadingObserved = false;
      viewModel.addListener(() {
        if (viewModel.state == NoteLoadState.loading && !loadingObserved) {
          loadingObserved = true;
          errorAtLoadingMoment = viewModel.error;
        }
      });

      await viewModel.load();

      expect(loadingObserved, isTrue);
      expect(errorAtLoadingMoment, isNull);
      expect(viewModel.state, NoteLoadState.success);
      expect(viewModel.error, isNull);
    });

    test('防重入：loading 中重複呼叫 load，loader 只被呼叫一次', () async {
      final loader = _FakeLoader()..markdown = _sampleMarkdown;
      final viewModel = NoteViewModel(
        loader: loader,
        parser: MarkdownSectionParser(),
        source: _testSource,
      );

      final firstLoad = viewModel.load();
      final secondLoad = viewModel.load();
      await Future.wait([firstLoad, secondLoad]);

      expect(loader.loadCalls, 1);
      expect(viewModel.state, NoteLoadState.success);
    });
  });
}
