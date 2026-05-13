// note_page.dart
//
// 個別分析師頁面：Banner（縮圖 + 名字 + 投顧）+ 日期 TabBar + TabBarView。
// 結構跟 HomePage 對齊（共用 DateTabBar / SectionView），差別只在頭部：
// - HomePage：Banner「分析師對照資料」+ 分析師 Row
// - NotePage：Banner（個別分析師資訊 + 返回按鈕）

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';

import '../models/note_source.dart';
import '../services/markdown_loader.dart';
import '../services/markdown_section_parser.dart';
import '../theme/markdown_styles.dart';
import 'widgets/date_tab_bar.dart';
import 'widgets/section_view.dart';

class NotePage extends StatefulWidget {
  const NotePage({super.key, required this.source});

  final NoteSource source;

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  final _loader = MarkdownLoader();
  final _parser = MarkdownSectionParser();
  late Future<_NoteData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<_NoteData> _load() async {
    final markdown = await _loader.load(widget.source.assetPath);
    final sections = _parser.parse(markdown);
    return _NoteData(rawMarkdown: markdown, sections: sections);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<_NoteData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _BackButton(),
                    const SizedBox(height: 16),
                    Text('載入失敗：${snapshot.error}'),
                  ],
                ),
              ),
            );
          }
          final data = snapshot.data!;
          if (data.sections.isEmpty) {
            // 沒有日期區段 → 退回整檔渲染（fallback 給未來不符合日期格式的檔案）
            return _FallbackFullView(
              source: widget.source,
              markdown: data.rawMarkdown,
            );
          }
          return _NoteBody(source: widget.source, sections: data.sections);
        },
      ),
    );
  }
}

/// 載入結果 — 同時保留原始 markdown 與已 parse 的 sections，
/// 讓 fallback view 不用重新載一次檔
class _NoteData {
  const _NoteData({required this.rawMarkdown, required this.sections});
  final String rawMarkdown;
  final List<MarkdownSection> sections;
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
