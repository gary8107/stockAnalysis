// note_page.dart
//
// 個別分析師頁面：Banner（縮圖 + 名字 + 投顧）+ 日期 TabBar + TabBarView。
// 結構跟 HomePage 對齊（共用 DateTabBar / BlockListView），差別只在頭部：
// - HomePage：Banner「分析師對照資料」+ 分析師 Row
// - NotePage：Banner（個別分析師資訊 + 返回按鈕）
//
// State management：NoteViewModel (ChangeNotifier) 對接 NotesApiService。
// View 訂閱 VM 狀態並渲染，載入邏輯封裝在 VM；analystKey 從 router 帶進來、
// 傳給 VM 建構式，view 內部從 viewModel.analyst 讀 metadata（單一 source of truth）。

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/analyst.dart';
import '../../models/note_entry.dart';
import '../../services/notes_api_service.dart';
import '../../viewmodels/note_view_model.dart';
import 'widgets/block_renderer.dart';
import 'widgets/date_tab_bar.dart';

class NotePage extends StatelessWidget {
  const NotePage({super.key, required this.analystKey});

  /// 由 router 從 path 取得（/note/:key）；建構式傳給 NoteViewModel
  final String analystKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChangeNotifierProvider<NoteViewModel>(
        create: (context) => NoteViewModel(
          api: context.read<NotesApiService>(),
          analystKey: analystKey,
        )..load(),
        child: Consumer<NoteViewModel>(
          builder: (context, viewModel, _) {
            switch (viewModel.state) {
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
                final analyst = viewModel.analyst;
                if (analyst == null) {
                  // analystKey 在 NotesIndex.analysts 找不到對映：
                  // 通常代表手動輸入錯誤的 URL，或資料尚未同步
                  return SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _BackButton(),
                          const SizedBox(height: 16),
                          Text('找不到這位分析師（key=${viewModel.analystKey}）'),
                        ],
                      ),
                    ),
                  );
                }
                if (viewModel.entries.isEmpty) {
                  return SafeArea(
                    child: Column(
                      children: [
                        _NoteBanner(analyst: analyst),
                        const Expanded(
                          child: Center(child: Text('這位分析師目前沒有筆記')),
                        ),
                      ],
                    ),
                  );
                }
                return _NoteBody(
                  analyst: analyst,
                  entries: viewModel.entries,
                );
            }
          },
        ),
      ),
    );
  }
}

class _NoteBody extends StatelessWidget {
  const _NoteBody({required this.analyst, required this.entries});

  final Analyst analyst;
  final List<NoteEntry> entries;

  @override
  Widget build(BuildContext context) {
    // 依日期分組：同一天可能有多篇（如陳昆仁盤前/盤後），合併成同一個日期 Tab，
    // 篇與篇之間改用內容上方的 segment 切換，避免出現重複日期的 Tab。
    final groups = _groupByDate(entries);
    return DefaultTabController(
      length: groups.length,
      child: SafeArea(
        child: Column(
          children: [
            _NoteBanner(analyst: analyst),
            // 每個日期只給 DateTabBar 一筆代表 entry（取第一篇）→ Tab 一日一個
            DateTabBar(entries: [for (final group in groups) group.first]),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                children: [
                  for (final group in groups) _DatePage(entries: group),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 依日期分組，保留原本顯示順序（新到舊；同日多篇保留檔案順序，如 盤後→盤前）。
  // 用 putIfAbsent 的 callback 記錄首次出現的日期順序，確保 group 順序穩定。
  static List<List<NoteEntry>> _groupByDate(List<NoteEntry> entries) {
    final byDate = <String, List<NoteEntry>>{};
    final dateOrder = <String>[];
    for (final entry in entries) {
      byDate.putIfAbsent(entry.date, () {
        dateOrder.add(entry.date);
        return <NoteEntry>[];
      }).add(entry);
    }
    // 日期維持新到舊；同日多篇依場次排成「盤前 → 盤後 → 其他」
    return [for (final date in dateOrder) _sortSessions(byDate[date]!)];
  }

  // 同日多篇排序：盤前在左、盤後在右、其他場次排最後（同 rank 保留原順序）。
  static List<NoteEntry> _sortSessions(List<NoteEntry> group) {
    if (group.length <= 1) return group;
    final indexed = [
      for (var i = 0; i < group.length; i++) (index: i, entry: group[i]),
    ];
    indexed.sort((a, b) {
      final byRank = _sessionRank(a.entry).compareTo(_sessionRank(b.entry));
      return byRank != 0 ? byRank : a.index.compareTo(b.index);
    });
    return [for (final item in indexed) item.entry];
  }

  static int _sessionRank(NoteEntry entry) {
    final label = entry.displayNote?.split(' · ').first ?? '';
    if (label.contains('盤前')) return 0;
    if (label.contains('盤後')) return 1;
    return 2;
  }
}

/// 單一日期的內容頁。
/// - 該日只有一篇：直接渲染內容。
/// - 該日多篇（如陳昆仁盤前/盤後）：上方放 segment 切換、下方渲染選中那篇。
class _DatePage extends StatefulWidget {
  const _DatePage({required this.entries});

  /// 同一個日期底下的所有篇（至少一篇）
  final List<NoteEntry> entries;

  @override
  State<_DatePage> createState() => _DatePageState();
}

class _DatePageState extends State<_DatePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    // 單篇：不顯示 segment，直接渲染
    if (entries.length == 1) {
      return BlockListView(blocks: entries.first.blocks);
    }

    // clamp 防呆：理論上不會越界，保險用
    final selected = _selectedIndex.clamp(0, entries.length - 1);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              for (var i = 0; i < entries.length; i++)
                ButtonSegment<int>(
                  value: i,
                  label: Text(_segmentLabel(entries[i], i)),
                ),
            ],
            selected: {selected},
            onSelectionChanged: (selection) =>
                setState(() => _selectedIndex = selection.first),
          ),
        ),
        Expanded(child: BlockListView(blocks: entries[selected].blocks)),
      ],
    );
  }

  // segment 標籤：取副標「 · 」前的短名（如「盤後 · 驚爆…」→「盤後」）；
  // 沒有有意義副標時退回「第 N 篇」。
  String _segmentLabel(NoteEntry entry, int index) {
    final note = entry.displayNote;
    if (note == null || note.isEmpty) return '第 ${index + 1} 篇';
    return note.split(' · ').first.trim();
  }
}

class _NoteBanner extends StatelessWidget {
  const _NoteBanner({required this.analyst});

  final Analyst analyst;

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
                analyst.thumbnail,
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
                  analyst.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  analyst.description,
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
