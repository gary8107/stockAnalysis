// note_view_model_test.dart
//
// NoteViewModel 單元測試（Phase 2.5：依賴 NotesApiService 後的版本）。
// 結構對齊 HomeViewModel 測試；多測 analystKey 過濾與「key 找不到」的 case。

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_analysis/models/analyst.dart';
import 'package:stock_analysis/models/note_block.dart';
import 'package:stock_analysis/models/note_entry.dart';
import 'package:stock_analysis/models/notes_index.dart';
import 'package:stock_analysis/services/notes_api_service.dart';
import 'package:stock_analysis/viewmodels/note_view_model.dart';

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

const _ruan = Analyst(
  key: 'ruan-huici',
  name: '阮蕙慈',
  description: '大華國際投顧',
);

const _li = Analyst(
  key: 'li-shufang',
  name: '李蜀芳',
  description: '永誠國際投顧',
);

final _ruanEntry1 = NoteEntry(
  date: '2026-05-15',
  note: '影片日期',
  blocks: const [MarkdownBlock(content: '阮的內容')],
  analystKey: 'ruan-huici',
);

final _ruanEntry2 = NoteEntry(
  date: '2026-05-14',
  note: '影片日期',
  blocks: const [MarkdownBlock(content: '阮的另一天')],
  analystKey: 'ruan-huici',
);

final _liEntry = NoteEntry(
  date: '2026-05-15',
  note: null,
  blocks: const [MarkdownBlock(content: '李的內容')],
  analystKey: 'li-shufang',
);

NotesIndex _buildIndex({
  List<Analyst> analysts = const [_ruan, _li],
  List<NoteEntry> notes = const [],
}) {
  return NotesIndex(
    version: '1.0',
    generatedAt: DateTime.utc(2026, 5, 18),
    analysts: analysts,
    comparisons: const [],
    notes: notes,
  );
}

void main() {
  group('NoteViewModel', () {
    test('初始狀態：idle、analyst null、entries 空、error null、analystKey 等於建構參數',
        () {
      final viewModel = NoteViewModel(
        api: _FakeNotesApi(),
        analystKey: 'ruan-huici',
      );

      expect(viewModel.state, NoteLoadState.idle);
      expect(viewModel.analyst, isNull);
      expect(viewModel.entries, isEmpty);
      expect(viewModel.error, isNull);
      expect(viewModel.analystKey, 'ruan-huici');
    });

    test('load 成功：analyst metadata 與 entries 一起填入；entries 只含該 key 的資料',
        () async {
      final api = _FakeNotesApi()
        ..response = _buildIndex(notes: [_ruanEntry1, _ruanEntry2, _liEntry]);
      final viewModel = NoteViewModel(api: api, analystKey: 'ruan-huici');

      await viewModel.load();

      expect(viewModel.state, NoteLoadState.success);
      expect(viewModel.analyst, _ruan);
      // 過濾正確：只回 ruan-huici 的兩筆，不含 li-shufang 那筆
      expect(viewModel.entries, hasLength(2));
      expect(
        viewModel.entries.map((entry) => entry.date),
        ['2026-05-15', '2026-05-14'],
      );
    });

    test('load 成功但 analystKey 找不到對映：analyst 為 null、entries 空（但 state 仍是 success）',
        () async {
      final api = _FakeNotesApi()..response = _buildIndex(notes: [_ruanEntry1]);
      final viewModel = NoteViewModel(api: api, analystKey: 'unknown-key');

      await viewModel.load();

      expect(viewModel.state, NoteLoadState.success);
      expect(viewModel.analyst, isNull);
      expect(viewModel.entries, isEmpty);
    });

    test('load 失敗：state 變 error、analyst / entries 不被污染', () async {
      final viewModel = NoteViewModel(
        api: _FakeNotesApi()..error = 'boom',
        analystKey: 'ruan-huici',
      );

      await viewModel.load();

      expect(viewModel.state, NoteLoadState.error);
      expect(viewModel.error, 'boom');
      expect(viewModel.analyst, isNull);
      expect(viewModel.entries, isEmpty);
    });

    test('retry：新一輪 load 進入 loading 當下就清掉舊 error', () async {
      final api = _FakeNotesApi()..error = 'boom';
      final viewModel = NoteViewModel(api: api, analystKey: 'ruan-huici');
      await viewModel.load();
      expect(viewModel.error, 'boom');

      api.error = null;
      api.response = _buildIndex(notes: [_ruanEntry1]);

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

    test('防重入：loading 中重複呼叫 load，api 只被呼叫一次', () async {
      final api = _FakeNotesApi()..response = _buildIndex();
      final viewModel = NoteViewModel(api: api, analystKey: 'ruan-huici');

      final firstLoad = viewModel.load();
      final secondLoad = viewModel.load();
      await Future.wait([firstLoad, secondLoad]);

      expect(api.loadCalls, 1);
      expect(viewModel.state, NoteLoadState.success);
    });
  });
}
