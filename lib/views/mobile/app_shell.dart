// app_shell.dart
//
// App 整體骨架：底部 BottomNav（對照 / 分析師 / 設定）+ IndexedStack 保留各 Tab state。
// 對應 SwiftUI 的 TabView，但用 IndexedStack 讓三個頁面的 scroll / VM state 切 Tab 時不會 reset。
//
// 為什麼用 StatefulWidget + IndexedStack 而非 StatefulShellRoute.indexedStack：
// - 第一版只需要 Tab 切換、不需要每個 Tab 內各自有獨立 deep link
// - IndexedStack 直接保留 widget state，最少程式碼能達到「切 Tab 不掉 state」
// - 後續需要每 Tab 內 push 子頁（例如「對照詳細頁」）時，可以在對應頁面內部用 Navigator.push 解決，不必動到 GoRouter 結構

import 'package:flutter/material.dart';

import 'analyst_list_page.dart';
import 'comparison_home_page.dart';
import 'settings_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  // 三個 Tab 的內容頁。const list 避免每次 rebuild 重新 new 一份頁面 widget
  // 注意：IndexedStack 會把所有頁面同時放進 widget tree（但只顯示其中一個），
  // 所以 HomeViewModel 等資源在進入 App 後就會載入，後續切 Tab 不再重 fetch
  static const _pages = <Widget>[
    ComparisonHomePage(),
    AnalystListPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.compare_arrows_outlined),
            selectedIcon: Icon(Icons.compare_arrows),
            label: '對照',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: '分析師',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '設定',
          ),
        ],
      ),
    );
  }
}
