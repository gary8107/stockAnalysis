// main.dart
//
// **Web entry**（桌機 / 平板尺寸用）。CI 部署到 GitHub Pages 跑 `flutter build web`
// 預設就走這個 entry。手機 App 改用 lib/main_mobile.dart（BottomNav 重新設計版面）。
//
// 兩 entry 差異：
// - Web (main.dart)：路由 / → HomePage（一頁式 Banner + 分析師 Row + 日期 TabBar）
// - Mobile (main_mobile.dart)：路由 / → AppShell（BottomNav 3 Tab）
// 共用層：models / services / viewmodels / theme / 多數 widgets / NotePage
//
// 為什麼 StockAnalysisApp 接 optional notesApiService：
// 讓 widget test 能注入 fake service，否則 test 環境下 http.get 拉不到
// 真 endpoint 會 fail。預設仍 new 一個真正的 NotesApiService（web 同 origin
// 走 `/api/notes.json`）。

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'services/notes_api_service.dart';
import 'views/web/home_page.dart';
import 'views/shared/note_page.dart';

void main() {
  runApp(const StockAnalysisApp());
}

// 把 router 抽成頂層常數而非建在 build 內，避免每次 rebuild 都重建一份新的 router
final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      // 用 analyst key 路由（取代 Phase 2 的 index 數字）：URL 可讀
      // （/note/ruan-huici）、新增/刪除分析師也不會洗掉舊 URL；
      // VM 內部用 key 對映 Analyst metadata
      path: '/note/:key',
      builder: (context, state) {
        final key = state.pathParameters['key'] ?? '';
        return NotePage(analystKey: key);
      },
    ),
  ],
);

class StockAnalysisApp extends StatelessWidget {
  const StockAnalysisApp({super.key, this.notesApiService});

  /// 測試環境注入 fake service 用；正式環境傳 null 走預設值
  final NotesApiService? notesApiService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<NotesApiService>(
          create: (_) => notesApiService ?? NotesApiService(),
        ),
      ],
      child: MaterialApp.router(
        title: '分析師筆記',
        debugShowCheckedModeBanner: false,
        routerConfig: _router,
        // Material 3 + 動態色：之後可以改成跟分析師對應的色彩
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
        // 跟系統深淺色——之後 Phase 4 加手動切換 button
        themeMode: ThemeMode.system,
      ),
    );
  }
}
