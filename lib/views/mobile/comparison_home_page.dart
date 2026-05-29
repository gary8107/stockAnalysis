// comparison_home_page.dart
//
// 對照 Tab 首頁：上方輪播 Banner（三位分析師）+ 下方日期 List（跨家對照）。
// 點擊日期 → 之後 push 到「該日對照詳細頁」（暫時 SnackBar placeholder）。
// 點擊 Banner 上某位分析師 → 之後 push 到「該分析師個別頁」（暫時 SnackBar placeholder）。
//
// 設計取捨：
// - 沿用既有 HomeViewModel：comparisons + analysts 一次載入完整，跟之前 Web 版共用 fetch 邏輯
// - View 端用 Consumer 訂閱四態 enum（idle / loading / success / error），符合既有架構
// - 不在這頁做日期 Tab 切換（與舊 HomePage 行為不同）：日期 List 是「導覽起點」而非「內容切換」

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/analyst.dart';
import '../../models/note_entry.dart';
import '../../services/notes_api_service.dart';
import '../../viewmodels/home_view_model.dart';
import 'widgets/analyst_banner_carousel.dart';

class ComparisonHomePage extends StatelessWidget {
  const ComparisonHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分析師資料對照'),
        centerTitle: true,
      ),
      body: ChangeNotifierProvider<HomeViewModel>(
        create: (context) => HomeViewModel(
          api: context.read<NotesApiService>(),
        )..load(),
        child: Consumer<HomeViewModel>(
          builder: (context, viewModel, _) {
            switch (viewModel.state) {
              case HomeLoadState.idle:
              case HomeLoadState.loading:
                return const Center(child: CircularProgressIndicator());
              case HomeLoadState.error:
                return _ErrorView(
                  message: '${viewModel.error}',
                  onRetry: () => viewModel.load(),
                );
              case HomeLoadState.success:
                if (viewModel.comparisons.isEmpty) {
                  return const Center(child: Text('沒有對照資料'));
                }
                return _Body(
                  analysts: viewModel.analysts,
                  comparisons: viewModel.comparisons,
                );
            }
          },
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.analysts, required this.comparisons});

  final List<Analyst> analysts;
  final List<NoteEntry> comparisons;

  @override
  Widget build(BuildContext context) {
    // Banner 移出 CustomScrollView、改放進 Column 的固定區：
    // 這樣下滑捲動時 Banner 會固定在頂部（AppBar 下方），不會跟著清單滾上去。
    // 只有下半部的「對照日期」清單包在 Expanded 內、可獨立捲動。
    return Column(
      children: [
        AnalystBannerCarousel(
          analysts: analysts,
          // push 而非 go：保留底部 BottomNav 的 Tab state，返回鍵 pop 回對照頁
          onAnalystTap: (analyst) => context.push('/note/${analyst.key}'),
        ),
        Expanded(
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    '對照日期',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              SliverList.separated(
                itemCount: comparisons.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = comparisons[index];
                  return _DateListTile(
                    entry: entry,
                    // push 而非 go：返回鍵 pop 回對照首頁，保留捲動位置與 BottomNav state
                    onTap: () => context.push('/comparison/${entry.date}'),
                  );
                },
              ),
              // 底部留空避免最後一筆貼著螢幕底邊
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ],
    );
  }
}

class _DateListTile extends StatelessWidget {
  const _DateListTile({required this.entry, required this.onTap});

  final NoteEntry entry;
  final VoidCallback onTap;

  /// 把 ISO 日期轉成 "2026-05-22 週四" 這種好讀格式。
  /// 解析失敗（資料異常）時回傳原字串，避免整頁 crash
  String _formatDate(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return iso;
    try {
      final dateTime = DateTime(year, month, day);
      const weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];
      // DateTime.weekday：週一=1 ... 週日=7，所以減 1 對應陣列 index
      final weekday = weekdayNames[dateTime.weekday - 1];
      return '$iso 週$weekday';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = entry.displayNote;
    return ListTile(
      onTap: onTap,
      leading: const CircleAvatar(
        child: Icon(Icons.calendar_today_outlined, size: 18),
      ),
      title: Text(
        _formatDate(entry.date),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle != null && subtitle.isNotEmpty
          ? Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

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
        crossAxisAlignment: CrossAxisAlignment.center,
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
