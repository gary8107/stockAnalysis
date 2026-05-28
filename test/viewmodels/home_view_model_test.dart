// home_view_model_test.dart
//
// HomeViewModel 單元測試（Phase 2.5：依賴 NotesApiService 後的版本）。
//
// 為什麼用 test() 而不是 testWidgets()：
// VM 是純 Dart 邏輯不依賴 widget tree；不用 pumpWidget 啟動框架，
// 測試跑得更快、訊號也更聚焦在 VM 狀態機本身。

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_analysis/models/analyst.dart';
import 'package:stock_analysis/models/note_block.dart';
import 'package:stock_analysis/models/note_entry.dart';
import 'package:stock_analysis/models/notes_index.dart';
import 'package:stock_analysis/services/notes_api_service.dart';
import 'package:stock_analysis/viewmodels/home_view_model.dart';

// 假 NotesApiService：繼承真實 class 並 override load()。
// 用 plain Dart 取代 mocktail/mockito，依賴更少、意圖更明顯
class _FakeNotesApi extends NotesApiService {
  _FakeNotesApi();

  NotesIndex? response;
  Object? error;
  int loadCalls = 0;

  @override
  Future<NotesIndex> load() async {
    loadCalls++;
    if (error != null) throw error!;
    if (response != null) return response!;
    throw StateError('Fake API: no response or error configured');
  }
}

NotesIndex _buildIndex({
  List<Analyst> analysts = const [],
  List<NoteEntry> comparisons = const [],
  List<NoteEntry> notes = const [],
}) {
  return NotesIndex(
    version: '1.0',
    generatedAt: DateTime.utc(2026, 5, 18),
    analysts: analysts,
    comparisons: comparisons,
    notes: notes,
  );
}

const _sampleAnalyst = Analyst(
  key: 'ruan-huici',
  name: '阮蕙慈',
  description: '大華國際投顧',
);

final _sampleComparison = NoteEntry(
  date: '2026-05-15',
  note: '對照日期',
  blocks: const [MarkdownBlock(content: '## 內容')],
);

void main() {
  group('HomeViewModel', () {
    test('初始狀態：idle、comparisons / analysts 空、error null', () {
      final viewModel = HomeViewModel(api: _FakeNotesApi());

      expect(viewModel.state, HomeLoadState.idle);
      expect(viewModel.comparisons, isEmpty);
      expect(viewModel.analysts, isEmpty);
      expect(viewModel.error, isNull);
    });

    test('load 成功：state loading → success，comparisons 與 analysts 同步填入',
        () async {
      final stateLog = <HomeLoadState>[];
      final api = _FakeNotesApi()
        ..response = _buildIndex(
          analysts: [_sampleAnalyst],
          comparisons: [_sampleComparison],
        );
      final viewModel = HomeViewModel(api: api);
      viewModel.addListener(() => stateLog.add(viewModel.state));

      await viewModel.load();

      expect(stateLog, [HomeLoadState.loading, HomeLoadState.success]);
      expect(viewModel.comparisons, hasLength(1));
      expect(viewModel.comparisons.first.date, '2026-05-15');
      expect(viewModel.analysts, [_sampleAnalyst]);
      expect(viewModel.error, isNull);
    });

    test('load 失敗：state loading → error，error 有值、collections 不變', () async {
      final stateLog = <HomeLoadState>[];
      final viewModel = HomeViewModel(api: _FakeNotesApi()..error = 'boom');
      viewModel.addListener(() => stateLog.add(viewModel.state));

      await viewModel.load();

      expect(stateLog, [HomeLoadState.loading, HomeLoadState.error]);
      expect(viewModel.error, 'boom');
      expect(viewModel.comparisons, isEmpty);
      expect(viewModel.analysts, isEmpty);
    });

    test('retry：新一輪 load 在進入 loading 當下就清掉舊 error', () async {
      final api = _FakeNotesApi()..error = 'boom';
      final viewModel = HomeViewModel(api: api);
      await viewModel.load();
      expect(viewModel.error, 'boom');

      // 修好 API，第二輪
      api.error = null;
      api.response = _buildIndex(comparisons: [_sampleComparison]);

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

    test('防重入：loading 中重複呼叫 load，api 只被呼叫一次', () async {
      final api = _FakeNotesApi()..response = _buildIndex();
      final viewModel = HomeViewModel(api: api);

      // 不 await 第一次，立刻發第二次；此時 _state 已是 loading，第二次應立即 return
      final firstLoad = viewModel.load();
      final secondLoad = viewModel.load();
      await Future.wait([firstLoad, secondLoad]);

      expect(api.loadCalls, 1);
      expect(viewModel.state, HomeLoadState.success);
    });
  });
}
