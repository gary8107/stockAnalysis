// section_view.dart
//
// 共用的單一日期區段內容渲染器。
// 把「markdown 渲染 + 共用 style sheet」綁在一起，HomePage 和 NotePage 都用。

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../services/markdown_section_parser.dart';
import '../../theme/markdown_styles.dart';

class SectionView extends StatelessWidget {
  const SectionView({super.key, required this.section});

  final MarkdownSection section;

  @override
  Widget build(BuildContext context) {
    return Markdown(
      data: section.content,
      // 讓使用者選取文字、複製股票代號或段落
      selectable: true,
      padding: const EdgeInsets.all(24),
      styleSheet: appMarkdownStyle(context),
    );
  }
}
