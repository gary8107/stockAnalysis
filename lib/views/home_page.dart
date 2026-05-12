// home_page.dart
//
// 首頁：列出所有筆記來源（3 位分析師 + 1 個對照檔）。
// 點任一張卡片 → push 到 /note/:index 詳細頁。
//
// 設計取捨：採 YouTube 縮圖式列表卡片（左 16:9 thumbnail + 右文字），
// 對比早期版本的「圓形小頭像」，更能保留節目縮圖完整資訊（人物 + 商標 + 標題）。

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/note_source.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final sources = NoteSource.all;

    return Scaffold(
      appBar: AppBar(
        title: const Text('分析師筆記'),
        centerTitle: false,
      ),
      body: ListView.separated(
        // 加上 padding 讓桌機與手機都有合理留白
        padding: const EdgeInsets.all(16),
        itemCount: sources.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final source = sources[index];
          return _SourceCard(
            source: source,
            onTap: () => context.go('/note/$index'),
          );
        },
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.source, required this.onTap});

  final NoteSource source;
  final VoidCallback onTap;

  // 縮圖固定寬度，搭配 16:9 比例算出高度 (160 / 16 * 9 = 90)
  // 為什麼寫死寬度而非用 Flexible：列表卡片要保持節奏一致，每張縮圖大小相同
  static const _thumbnailWidth = 160.0;
  static const _thumbnailHeight = 90.0;

  @override
  Widget build(BuildContext context) {
    return Card(
      // clipBehavior 讓子元素（包含 thumbnail）按 Card 的圓角裁切，
      // 否則圖片會超出圓角範圍
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            _Thumbnail(
              asset: source.thumbnailAsset,
              width: _thumbnailWidth,
              height: _thumbnailHeight,
              isComparison: source.kind == NoteKind.comparison,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      source.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      source.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.asset,
    required this.width,
    required this.height,
    required this.isComparison,
  });

  final String asset;
  final double width;
  final double height;
  final bool isComparison;

  @override
  Widget build(BuildContext context) {
    // 對照檔的 cartoon placeholder 是線稿風 PNG，背景透明且圖案小，
    // 用單純 BoxFit.cover 會被放大失真；改用 contain + 漸層底色比較得體
    if (isComparison) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.tertiaryContainer,
              Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.3),
            ],
          ),
        ),
        child: Image.asset(asset, fit: BoxFit.contain),
      );
    }

    // 分析師節目縮圖：1280x720 直接 cover 進 160x90 視窗，保留主要構圖
    return SizedBox(
      width: width,
      height: height,
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        // 載入失敗時退回到佔位 icon，避免缺圖造成版面塌陷
        errorBuilder: (context, error, stackTrace) => ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: const Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }
}
