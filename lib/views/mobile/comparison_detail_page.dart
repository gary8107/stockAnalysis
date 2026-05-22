// comparison_detail_page.dart
//
// 對照詳細頁：點對照首頁的某個日期 ListTile 後 push 到這頁，顯示「該日所有
// 跨分析師對照內容」（用既有 BlockListView 渲染 NoteEntry.blocks）。
//
// 為什麼 AppBar 內標題用「對照 · 5/22 週四」這種簡寫而非完整 ISO 日期：
// AppBar 寬度有限，完整 "2026-05-22 週四" 在小尺寸（iPhone SE）會擠壓返回鍵；
// 月日對使用者已足夠辨識，年份在內文副標可以再次出現。
//
// 為什麼用 ChangeNotifierProvider 包在 build() 內而非 main_mobile.dart 全域：
// VM 接收 date 參數，每次 push 進新日期就要新 VM；放全域 Provider 反而麻煩。
// VM 依賴 NotesApiService（全域 Provider 提供）所以 context.read 取得即可。

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/note_entry.dart';
import '../../services/notes_api_service.dart';
import '../../viewmodels/comparison_detail_view_model.dart';
import '../shared/widgets/block_renderer.dart';

class ComparisonDetailPage extends StatelessWidget {
  const ComparisonDetailPage({super.key, required this.date});

  /// 由 router path param 帶入；建構式傳給 VM 用來過濾出對應 entry
  final String date;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ComparisonDetailViewModel>(
      create: (context) => ComparisonDetailViewModel(
        api: context.read<NotesApiService>(),
        date: date,
      )..load(),
      child: Consumer<ComparisonDetailViewModel>(
        builder: (context, viewModel, _) {
          return Scaffold(
            appBar: AppBar(
              title: Text(_formatDateForAppBar(date)),
            ),
            body: _buildBody(context, viewModel),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, ComparisonDetailViewModel viewModel) {
    switch (viewModel.state) {
      case ComparisonDetailLoadState.idle:
      case ComparisonDetailLoadState.loading:
        return const Center(child: CircularProgressIndicator());

      case ComparisonDetailLoadState.error:
        return _ErrorView(
          message: '${viewModel.error}',
          onRetry: () => viewModel.load(),
        );

      case ComparisonDetailLoadState.success:
        final entry = viewModel.entry;
        if (entry == null) {
          // 該日期不在 comparisons——多半是 URL 帶錯日期 / 資料尚未同步
          // 與「載入失敗」分開：不顯示 retry 按鈕（重打 fetch 也不會出現）
          return _NotFoundView(date: date);
        }
        return _DetailBody(entry: entry);
    }
  }

  /// AppBar 標題用「對照 · 5/22 週四」這種短格式；解析失敗 fallback 用原字串
  String _formatDateForAppBar(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) return '對照 · $iso';
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    final year = int.tryParse(parts[0]);
    if (month == null || day == null || year == null) return '對照 · $iso';
    try {
      final dateTime = DateTime(year, month, day);
      const weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];
      final weekday = weekdayNames[dateTime.weekday - 1];
      return '對照 · $month/$day 週$weekday';
    } catch (_) {
      return '對照 · $iso';
    }
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.entry});

  final NoteEntry entry;

  @override
  Widget build(BuildContext context) {
    final subtitle = entry.displayNote;
    final hasSubtitle = subtitle != null && subtitle.isNotEmpty;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 副標列（盤前 / 盤後 / 追高警告場 這類）；若無就不渲染這條，避免空白條
          if (hasSubtitle)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              child: Row(
                children: [
                  Icon(
                    Icons.label_important_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      subtitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          // BlockListView 內建 ListView.separated，blocks 多時也是 lazy build
          Expanded(
            child: BlockListView(blocks: entry.blocks),
          ),
        ],
      ),
    );
  }
}

/// 該日對照查無資料的提示——獨立出來避免把 not-found 跟 error 混在一起
class _NotFoundView extends StatelessWidget {
  const _NotFoundView({required this.date});

  final String date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_busy_outlined, size: 48),
          const SizedBox(height: 16),
          Text(
            '查無 $date 的對照資料',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '這天可能還沒整理對照，或資料尚未同步。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// 載入失敗顯示——含 retry 按鈕，與 _NotFoundView 區分（後者 retry 沒意義）
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 16),
          Text('載入對照資料失敗', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重試'),
          ),
        ],
      ),
    );
  }
}
