// block_renderer.dart
//
// 把一個 NoteBlock 渲染成對應的 widget。
// 取代 Phase 2 的 SectionView（後者是 markdown 字串一次渲染整段，
// 沒有 block-level 區分；現在 schema 結構化後 table 走 CompactTableView、
// 其他走 flutter_markdown）。
//
// 為什麼用單一 BlockRenderer 而非各 widget 自己處理：
// 之後新增 block type（heading / list / ...）只需要在這裡加 case，
// view 端不用動。sealed class NoteBlock 確保編譯期窮舉檢查。

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../models/note_block.dart';
import '../../../theme/markdown_styles.dart';
import 'compact_table_view.dart';

class BlockRenderer extends StatelessWidget {
  const BlockRenderer({super.key, required this.block});

  final NoteBlock block;

  @override
  Widget build(BuildContext context) {
    // 用 typed-variable pattern 直接 bind 整個 obj，比 object pattern + cast 乾淨
    return switch (block) {
      MarkdownBlock(:final content) => MarkdownBody(
          data: content,
          selectable: true,
          styleSheet: appMarkdownStyle(context),
        ),
      final TableBlock tableBlock => CompactTableView(table: tableBlock),
    };
  }
}

/// 一連串 blocks 的容器——常用情境是「一個 NoteEntry 的所有 blocks」。
/// 用 ListView 而非 Column + scroll，讓內容長時也有 lazy build。
class BlockListView extends StatelessWidget {
  const BlockListView({
    super.key,
    required this.blocks,
    this.padding = const EdgeInsets.all(24),
  });

  final List<NoteBlock> blocks;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      itemCount: blocks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) => BlockRenderer(block: blocks[index]),
    );
  }
}
