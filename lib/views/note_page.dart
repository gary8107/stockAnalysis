// note_page.dart
//
// 個別分析師頁面：Banner（縮圖 + 名字 + 投顧）+ 日期 TabBar + TabBarView。
// 結構跟 HomePage 對齊（共用 DateTabBar / SectionView），差別只在頭部：
// - HomePage：Banner「分析師對照資料」+ 分析師 Row
// - NotePage：Banner（個別分析師資訊 + 返回按鈕）
//
// State management：Phase 2 起改用 NoteViewModel (ChangeNotifier)
// View 只訂閱 VM 狀態並渲染，載入邏輯封裝在 VM；source 也由 VM 持有，
// View 內部都從 viewModel.source 讀，避免兩處保存同一份來源

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/note_source.dart';
import '../services/markdown_loader.dart';
import '../services/markdown_section_parser.dart';
import '../theme/markdown_styles.dart';
import '../viewmodels/note_view_model.dart';
import 'widgets/date_tab_bar.dart';
import 'widgets/section_view.dart';

class NotePage extends StatelessWidget {
  const NotePage({super.key, required this.source});

  /// 由 router 從 path index 取得；建構式傳給 NoteViewModel，
  /// 之後 View 內部都從 viewModel.source 讀
  final NoteSource source;

  @override
  Widget build(BuildContext context) {
    // 結構對齊 HomePage：頁面層 ChangeNotifierProvider 建 VM、
    // Consumer 訂閱 state 切換 view。
    return Scaffold(
      body: ChangeNotifierProvider<NoteViewModel>(
        create: (context) => NoteViewModel(
          loader: context.read<MarkdownLoader>(),
          parser: context.read<MarkdownSectionParser>(),
          source: source,
        )..load(),
        child: Consumer<NoteViewModel>(
          builder: (context, viewModel, _) {
            switch (viewModel.state) {
              // idle 理論上只會在 VM 剛建立、load() 還沒開始的極短時間出現；
              // 跟 loading 合併呈現轉圈圈，避免首幀閃過空白
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
                // 沒有日期區段 → 退回整檔渲染（fallback 給未來不符合日期
                // 格式的檔案）；rawMarkdown 從 VM 拿，不再 load 一次
                if (viewModel.sections.isEmpty) {
                  return _FallbackFullView(
                    source: viewModel.source,
                    markdown: viewModel.rawMarkdown,
                  );
                }
                return _NoteBody(
                  source: viewModel.source,
                  sections: viewModel.sections,
                );
            }
          },
        ),
      ),
    );
  }
}

class _NoteBody extends StatelessWidget {
  const _NoteBody({required this.source, required this.sections});

  final NoteSource source;
  final List<MarkdownSection> sections;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: sections.length,
      child: SafeArea(
        child: Column(
          children: [
            _NoteBanner(source: source),
            DateTabBar(sections: sections),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                children: sections
                    .map((s) => SectionView(section: s))
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
  const _NoteBanner({required this.source});

  final NoteSource source;

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
                source.thumbnailAsset,
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
                  source.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  source.description,
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

/// 沒有日期區段時的 fallback：整檔渲染
class _FallbackFullView extends StatelessWidget {
  const _FallbackFullView({required this.source, required this.markdown});

  final NoteSource source;
  final String markdown;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _NoteBanner(source: source),
          Expanded(
            child: Markdown(
              data: markdown,
              selectable: true,
              padding: const EdgeInsets.all(24),
              styleSheet: appMarkdownStyle(context),
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
