// widget_test.dart
//
// 最小 smoke test：確認 App 能起來、首頁標題渲染出來。
//
// Phase 2.5 後 NotesApiService 從遠端 fetch JSON，test 環境拉不到真 endpoint，
// 所以注入 fake service 返回 minimal valid NotesIndex，讓 HomePage 走到
// success 分支、Banner 文字才會出現。

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_analysis/main.dart';
import 'package:stock_analysis/models/note_entry.dart';
import 'package:stock_analysis/models/notes_index.dart';
import 'package:stock_analysis/services/notes_api_service.dart';

class _FakeNotesApi extends NotesApiService {
  _FakeNotesApi(this._index);
  final NotesIndex _index;

  @override
  Future<NotesIndex> load() async => _index;
}

void main() {
  testWidgets('App starts and shows home banner title', (tester) async {
    final fakeIndex = NotesIndex(
      version: '1.0',
      generatedAt: DateTime.utc(2026, 5, 18),
      analysts: const [],
      // HomePage success 分支需要至少 1 個 comparison 才會走到 _HomeBody；
      // comparisons 為空時 view 顯示「沒有對照資料」，找不到 Banner 文字
      comparisons: [
        NoteEntry.fromJson(const {
          'date': '2026-05-15',
          'note': '對照日期',
          'blocks': [],
        }),
      ],
      notes: const [],
    );

    await tester.pumpWidget(
      StockAnalysisApp(notesApiService: _FakeNotesApi(fakeIndex)),
    );
    // 等所有 frame 跑完（包含 router 初始化 + 假 API future 完成 + Consumer 重 build）
    await tester.pumpAndSettle();

    expect(find.text('分析師對照資料'), findsOneWidget);
  });
}
