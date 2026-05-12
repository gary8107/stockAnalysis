// home_page.dart
//
// 首頁：列出所有筆記來源（3 位分析師 + 1 個對照檔）。
// 點任一張卡片 → push 到 /note/:index 詳細頁。

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

  @override
  Widget build(BuildContext context) {
    // 用對照 vs. 分析師區分卡片強調色——之後想加 icon 也容易
    final isComparison = source.kind == NoteKind.comparison;
    final accent = isComparison
        ? Theme.of(context).colorScheme.tertiaryContainer
        : Theme.of(context).colorScheme.primaryContainer;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: accent,
                child: Icon(
                  isComparison ? Icons.compare_arrows : Icons.person,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      source.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
