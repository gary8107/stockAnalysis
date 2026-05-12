// widget_test.dart
//
// 最小 smoke test：確認 App 能起來、首頁標題渲染出來。
// 之後 Phase 加更多測試（model parsing、loader、navigation flow）時放這裡。

import 'package:flutter_test/flutter_test.dart';

import 'package:stock_analysis/main.dart';

void main() {
  testWidgets('App starts and shows home title', (WidgetTester tester) async {
    await tester.pumpWidget(const StockAnalysisApp());
    // 等所有 frame 跑完（包含 router 初始化）
    await tester.pumpAndSettle();

    expect(find.text('分析師筆記'), findsOneWidget);
  });
}
