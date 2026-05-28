// widget_test_mobile.dart
//
// Mobile entry (main_mobile.dart) smoke test。
// 確認手機 entry 起得來、AppShell BottomNav + ComparisonHomePage AppBar title 都渲染出來。
//
// 跑法：flutter test test/widget_test_mobile.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_analysis/main_mobile.dart';
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
  testWidgets('Mobile entry shows AppShell with BottomNav and ComparisonHomePage', (tester) async {
    final fakeIndex = NotesIndex(
      version: '1.0',
      generatedAt: DateTime.utc(2026, 5, 18),
      analysts: const [],
      // ComparisonHomePage success 分支需要至少 1 個 comparison 才會走到 _Body
      comparisons: [
        NoteEntry.fromJson(const {
          'date': '2026-05-22',
          'note': '對照日期',
          'blocks': [],
        }),
      ],
      notes: const [],
    );

    await tester.pumpWidget(
      StockAnalysisMobileApp(notesApiService: _FakeNotesApi(fakeIndex)),
    );
    await tester.pumpAndSettle();

    // ComparisonHomePage AppBar title（注意：與 Web HomePage 的「分析師對照資料」順序剛好相反）
    expect(find.text('分析師資料對照'), findsOneWidget);
    // BottomNav 三個 Tab label 都要在
    expect(find.text('對照'), findsOneWidget);
    expect(find.text('分析師'), findsOneWidget);
    expect(find.text('設定'), findsOneWidget);
  });
}
