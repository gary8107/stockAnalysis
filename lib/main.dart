// main.dart
//
// App 入口點。
// 架構選型備忘：
// - 路由：用 go_router（聲明式，類似 SwiftUI NavigationStack）
// - 主題：先用 Material 3 + ColorScheme.fromSeed；深淺色跟系統
// - State management：MVP 階段先 StatefulWidget + FutureBuilder 就夠用
//   Phase 2+ 加 ChangeNotifier viewmodels 時再導入 provider

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'models/note_source.dart';
import 'views/home_page.dart';
import 'views/note_page.dart';

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
      path: '/note/:index',
      builder: (context, state) {
        // index 在 path 裡是 String，轉成 int 來查 NoteSource.all
        // 之後如果改成用 name 當參數，這裡也只動一行
        final index = int.tryParse(state.pathParameters['index'] ?? '');
        if (index == null || index < 0 || index >= NoteSource.all.length) {
          return const Scaffold(
            body: Center(child: Text('找不到這份筆記')),
          );
        }
        return NotePage(source: NoteSource.all[index]);
      },
    ),
  ],
);

class StockAnalysisApp extends StatelessWidget {
  const StockAnalysisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
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
    );
  }
}
