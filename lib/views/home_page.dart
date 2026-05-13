// home_page.dart
//
// 首頁：以「對照資料」為核心 — Banner + 分析師 Tab + 日期 Tab + 對照內容。
// 點分析師卡片跳到該分析師完整檔；切日期 Tab 顯示對照檔內該日期區段。
//
// 設計取捨：
// - 對照檔載一次、parse 出所有日期區段，切日期不重新載檔（純切 view）
// - 分析師 Row 在桌機水平排、手機水平捲動（LayoutBuilder breakpoint 600dp）
// - TabBar isScrollable 處理未來日期增加的情境
// - State management 用 StatefulWidget + FutureBuilder + DefaultTabController
//   都是 Flutter 內建，沒導 provider，Phase 2 再升級

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/note_source.dart';
import '../services/markdown_loader.dart';
import '../services/markdown_section_parser.dart';
import 'widgets/date_tab_bar.dart';
import 'widgets/section_view.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _loader = MarkdownLoader();
  final _parser = MarkdownSectionParser();
  late Future<List<MarkdownSection>> _sectionsFuture;

  @override
  void initState() {
    super.initState();
    _sectionsFuture = _loadSections();
  }

  Future<List<MarkdownSection>> _loadSections() async {
    final markdown = await _loader.load(NoteSource.comparison.assetPath);
    return _parser.parse(markdown);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<MarkdownSection>>(
        future: _sectionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Text('載入對照資料失敗：${snapshot.error}'),
            );
          }
          final sections = snapshot.data ?? const [];
          if (sections.isEmpty) {
            return const Center(child: Text('沒有對照資料'));
          }
          return _HomeBody(sections: sections);
        },
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.sections});
  final List<MarkdownSection> sections;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: sections.length,
      child: SafeArea(
        child: Column(
          children: [
            const _Banner(),
            const _AnalystRow(),
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
  const _AnalystRow();

  // breakpoint：600dp 是 Material Design 通用「手機 / 平板」分界
  static const _wideBreakpoint = 600.0;

  @override
  Widget build(BuildContext context) {
    final analysts = NoteSource.analysts;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;
        if (isWide) {
          // 桌機 / 平板：3 卡水平 Expanded 等寬
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                for (var i = 0; i < analysts.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(
                    child: _AnalystMiniCard(
                      analyst: analysts[i],
                      onTap: () => context.go('/note/$i'),
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
                onTap: () => context.go('/note/$i'),
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
  final NoteSource analyst;
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
                analyst.thumbnailAsset,
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

// _DateTabBar 和 _SectionView 已抽出至 lib/views/widgets/ 共用
