// note_page.dart
//
// 詳細頁：載入並渲染單一筆記的 markdown 內容。
// 目前是「整個檔案丟進 Markdown widget 渲染」，Phase 2 會拆出左側日期側欄。

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';

import '../models/note_source.dart';
import '../services/markdown_loader.dart';

class NotePage extends StatefulWidget {
  const NotePage({super.key, required this.source});

  final NoteSource source;

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  // 把 MarkdownLoader 放在 service field，未來想換實作（例如 fetch 遠端）只動這裡
  final _loader = MarkdownLoader();
  late Future<String> _contentFuture;

  @override
  void initState() {
    super.initState();
    _contentFuture = _loader.load(widget.source.assetPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.source.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          // 用 go_router 的 go() 回首頁，避免 web 上 pop 導致空白
          onPressed: () => context.go('/'),
        ),
      ),
      body: FutureBuilder<String>(
        future: _contentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            // 顯示具體錯誤訊息，方便 debug——例如 asset 路徑打錯或忘記 sync
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Text('載入失敗：${snapshot.error}'),
            );
          }
          final markdown = snapshot.data ?? '';
          return Markdown(
            data: markdown,
            // 讓使用者可以選取文字、複製股票名稱 / 段落
            selectable: true,
            padding: const EdgeInsets.all(24),
          );
        },
      ),
    );
  }
}
