// home_page.dart
//
// 首頁：以「對照資料」為核心 — Banner + 分析師 Row + 日期 Tab + 對照內容。
// 點分析師卡片跳到該分析師完整檔；切日期 Tab 顯示對照檔內該日期 entry。
//
// 設計取捨：
// - 對照資料一次 fetch 後 parse 完成，切日期不重新載（純切 view）
// - 分析師 Row 在桌機水平排、手機水平捲動（LayoutBuilder breakpoint 600dp）
// - TabBar isScrollable 處理未來日期增加的情境
// - State management：HomeViewModel (ChangeNotifier) + DefaultTabController
//   View 訂閱 VM 狀態（idle/loading/success/error）並渲染，載入邏輯都在 VM
// - 表格不再水平捲動：每個 entry 的 blocks 用 BlockListView 渲染，table block
//   走 CompactTableView（固定欄寬 + tap cell 跳 dialog，解決手機 UX 痛點）

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/analyst.dart';
import '../../models/note_entry.dart';
import '../../services/notes_api_service.dart';
import '../../viewmodels/home_view_model.dart';
import '../shared/widgets/block_renderer.dart';
import '../shared/widgets/date_tab_bar.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChangeNotifierProvider<HomeViewModel>(
        create: (context) => HomeViewModel(
          api: context.read<NotesApiService>(),
        )..load(),
        child: Consumer<HomeViewModel>(
          builder: (context, viewModel, _) {
            switch (viewModel.state) {
              // idle 只會在 VM 剛建立、load() 還沒被呼叫的極短時間出現；
              // 跟 loading 合併呈現轉圈圈，避免首幀閃過空白
              case HomeLoadState.idle:
              case HomeLoadState.loading:
                return const Center(child: CircularProgressIndicator());
              case HomeLoadState.error:
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('載入對照資料失敗：${viewModel.error}'),
                );
              case HomeLoadState.success:
                final comparisons = viewModel.comparisons;
                if (comparisons.isEmpty) {
                  return const Center(child: Text('沒有對照資料'));
                }
                return _HomeBody(
                  entries: comparisons,
                  analysts: viewModel.analysts,
                );
            }
          },
        ),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.entries, required this.analysts});

  final List<NoteEntry> entries;
  final List<Analyst> analysts;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: entries.length,
      child: SafeArea(
        child: Column(
          children: [
            const _Banner(),
            _AnalystRow(analysts: analysts),
            DateTabBar(entries: entries),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                children: entries
                    .map((entry) => BlockListView(blocks: entry.blocks))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.primaryContainer],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '分析師對照資料',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '同日多位分析師觀點比對',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onPrimary.withValues(alpha: 0.85),
                ),
          ),
        ],
      ),
    );
  }
}

class _AnalystRow extends StatelessWidget {
  const _AnalystRow({required this.analysts});

  final List<Analyst> analysts;

  // breakpoint：600dp 是 Material Design 通用「手機 / 平板」分界
  static const _wideBreakpoint = 600.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;
        if (isWide) {
          // 桌機 / 平板：水平 Expanded 等寬
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                for (var i = 0; i < analysts.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(
                    child: _AnalystMiniCard(
                      analyst: analysts[i],
                      onTap: () => context.go('/note/${analysts[i].key}'),
                    ),
                  ),
                ],
              ],
            ),
          );
        }
        // 手機：水平捲動的 ListView，每張卡固定寬避免被擠扁
        return SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: analysts.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, i) => SizedBox(
              width: 260,
              child: _AnalystMiniCard(
                analyst: analysts[i],
                onTap: () => context.go('/note/${analysts[i].key}'),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnalystMiniCard extends StatelessWidget {
  const _AnalystMiniCard({required this.analyst, required this.onTap});

  final Analyst analyst;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 80,
              child: Image.asset(
                analyst.thumbnail,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      analyst.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      analyst.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
