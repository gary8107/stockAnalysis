// note_page.dart
//
// 個別分析師頁面：Banner（縮圖 + 名字 + 投顧）+ 日期 TabBar + TabBarView。
// 結構跟 HomePage 對齊（共用 DateTabBar / BlockListView），差別只在頭部：
// - HomePage：Banner「分析師對照資料」+ 分析師 Row
// - NotePage：Banner（個別分析師資訊 + 返回按鈕）
//
// State management：NoteViewModel (ChangeNotifier) 對接 NotesApiService。
// View 訂閱 VM 狀態並渲染，載入邏輯封裝在 VM；analystKey 從 router 帶進來、
// 傳給 VM 建構式，view 內部從 viewModel.analyst 讀 metadata（單一 source of truth）。

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/analyst.dart';
import '../models/note_entry.dart';
import '../services/notes_api_service.dart';
import '../viewmodels/note_view_model.dart';
import 'widgets/block_renderer.dart';
import 'widgets/date_tab_bar.dart';

class NotePage extends StatelessWidget {
  const NotePage({super.key, required this.analystKey});

  /// 由 router 從 path 取得（/note/:key）；建構式傳給 NoteViewModel
  final String analystKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChangeNotifierProvider<NoteViewModel>(
        create: (context) => NoteViewModel(
          api: context.read<NotesApiService>(),
          analystKey: analystKey,
        )..load(),
        child: Consumer<NoteViewModel>(
          builder: (context, viewModel, _) {
            switch (viewModel.state) {
              case NoteLoadState.idle:
              case NoteLoadState.loading:
                return const Center(child: CircularProgressIndicator());
              case NoteLoadState.error:
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _BackButton(),
                        const SizedBox(height: 16),
                        Text('載入失敗：${viewModel.error}'),
                      ],
                    ),
                  ),
                );
              case NoteLoadState.success:
                final analyst = viewModel.analyst;
                if (analyst == null) {
                  // analystKey 在 NotesIndex.analysts 找不到對映：
                  // 通常代表手動輸入錯誤的 URL，或資料尚未同步
                  return SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _BackButton(),
                          const SizedBox(height: 16),
                          Text('找不到這位分析師（key=${viewModel.analystKey}）'),
                        ],
                      ),
                    ),
                  );
                }
                if (viewModel.entries.isEmpty) {
                  return SafeArea(
                    child: Column(
                      children: [
                        _NoteBanner(analyst: analyst),
                        const Expanded(
                          child: Center(child: Text('這位分析師目前沒有筆記')),
                        ),
                      ],
                    ),
                  );
                }
                return _NoteBody(
                  analyst: analyst,
                  entries: viewModel.entries,
                );
            }
          },
        ),
      ),
    );
  }
}

class _NoteBody extends StatelessWidget {
  const _NoteBody({required this.analyst, required this.entries});

  final Analyst analyst;
  final List<NoteEntry> entries;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: entries.length,
      child: SafeArea(
        child: Column(
          children: [
            _NoteBanner(analyst: analyst),
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

class _NoteBanner extends StatelessWidget {
  const _NoteBanner({required this.analyst});

  final Analyst analyst;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.primaryContainer],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: colors.onPrimary),
            onPressed: () => context.go('/'),
            tooltip: '返回首頁',
          ),
          // 縮圖：16:9 但縮小尺寸，避免 Banner 占太多版面
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 96,
              height: 54,
              child: Image.asset(
                analyst.thumbnail,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: colors.surfaceContainerHigh,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  analyst.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  analyst.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onPrimary.withValues(alpha: 0.85),
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 錯誤狀態下的獨立返回按鈕（沒有 banner 包它）
class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => context.go('/'),
      tooltip: '返回首頁',
    );
  }
}
