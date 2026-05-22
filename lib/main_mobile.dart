// main_mobile.dart
//
// **Mobile App entry**（iOS / Android 用）。跑法：
//   flutter run -t lib/main_mobile.dart -d "iPhone 15 Pro"
//   flutter build ios -t lib/main_mobile.dart --release
//   flutter build apk -t lib/main_mobile.dart --release
//
// 與 Web entry (lib/main.dart) 的差異：
// - Web：路由 / → HomePage（一頁式 Banner + 分析師 Row + 日期 TabBar）
// - Mobile：路由 / → AppShell（BottomNav 3 Tab：對照 / 分析師 / 設定）
// 共用層：models / services / viewmodels / theme / 多數 widgets / NotePage 都共用
//
// 為什麼分兩個 entry 而非用 LayoutBuilder responsive：
// 1. Web 桌機版面與 Mobile BottomNav 互動模型差異大（日期 TabBar 切內容 vs List push 新頁）
//    一份 codebase 同時跑兩種互動模型容易在跨平台 widget 行為上出 bug（鍵盤 / 手勢 / 路由）
// 2. CI Web 部署用 main.dart 預設 entry 不受影響；行動端 build 顯式指定 -t lib/main_mobile.dart
// 3. 共用層仍占大多數（資料、VM、主題、Markdown 渲染、表格），維護成本可控

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'services/notes_api_service.dart';
import 'views/mobile/app_shell.dart';
import 'views/mobile/comparison_detail_page.dart';
import 'views/shared/note_page.dart';

void main() {
  runApp(const StockAnalysisMobileApp());
}

// 同樣抽到頂層常數避免每次 rebuild 都重建 router
final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const AppShell()),
    GoRoute(
      // 從 Banner 點某位分析師時可 push 到此路由；NotePage 既有 widget 在
      // 手機尺寸下仍可用，未來可再針對 mobile 重新設計版面
      path: '/note/:key',
      builder: (context, state) {
        final key = state.pathParameters['key'] ?? '';
        return NotePage(analystKey: key);
      },
    ),
    GoRoute(
      // 點對照首頁某個日期 ListTile 後 push 進這頁。
      // path param 用 ISO 字串（例 /comparison/2026-05-22）讓 URL 可分享
      path: '/comparison/:date',
      builder: (context, state) {
        final date = state.pathParameters['date'] ?? '';
        return ComparisonDetailPage(date: date);
      },
    ),
  ],
);

class StockAnalysisMobileApp extends StatelessWidget {
  const StockAnalysisMobileApp({super.key, this.notesApiService});

  /// 測試環境注入 fake service 用；正式環境傳 null 走預設值
  final NotesApiService? notesApiService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<NotesApiService>(
          create: (_) =>
              notesApiService ??
              NotesApiService(
                baseUrl: 'https://gary8107.github.io/stockAnalysis/',
              ),
        ),
      ],
      child: MaterialApp.router(
        title: '分析師筆記',
        debugShowCheckedModeBanner: false,
        routerConfig: _router,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigo,
            brightness: Brightness.dark,
          ),
        ),
        themeMode: ThemeMode.system,
      ),
    );
  }
}
