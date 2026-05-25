// analyst_note_page.dart
//
// **Mobile 專屬**的個別分析師內容頁。與 web 共用的 views/shared/note_page.dart 差異：
// - 日期切換：web 版用可橫向滑動的 DateTabBar + TabBarView；
//   mobile 版改成「下拉式選單選日期 + 單一內容區」（本頁）。
//   原因：手機上日期一多，橫向 TabBar 要左右撥找、且滑動手勢會與內容垂直捲動打架；
//   下拉選單一次展開全部日期、點選即跳，對單手操作更直覺。
// - 返回行為：mobile 是從卡片 / Banner `context.push` 進來的子頁，返回用 pop 回上一頁
//   （web 版是 go('/') 回首頁）。
//
// 共用層沿用：NoteViewModel（資料 + 四態 enum）、NotesApiService、BlockListView 渲染。
// 之所以不改共用 NotePage 而是新開一個檔：web 桌面版仍適合 TabBar，兩平台版面開始分化
// （見專案 roadmap「針對手機重新設計版面」），與其在共用檔塞 if (isMobile) 分支，
// 不如各自一個 view、共用底層資料與渲染元件。

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/analyst.dart';
import '../../models/note_entry.dart';
import '../../services/notes_api_service.dart';
import '../../viewmodels/note_view_model.dart';
import '../shared/widgets/block_renderer.dart';

class AnalystNotePage extends StatelessWidget {
  const AnalystNotePage({super.key, required this.analystKey});

  /// 由 router 從 path 取得（/note/:key），傳給 NoteViewModel
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
                return _MessageState(
                  message: '載入失敗：${viewModel.error}',
                );
              case NoteLoadState.success:
                final analyst = viewModel.analyst;
                if (analyst == null) {
                  // analystKey 在 NotesIndex.analysts 找不到對映：通常是手動輸入錯 URL
                  return _MessageState(
                    message: '找不到這位分析師（key=${viewModel.analystKey}）',
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
                return _NoteBody(analyst: analyst, entries: viewModel.entries);
            }
          },
        ),
      ),
    );
  }
}

/// 同一個日期底下的一到多筆 entry（例如陳昆仁同日有「盤前」+「盤後」兩支）。
/// 下拉選單以「日期」為單位（一組一項），組內多筆再用場次分段鈕切換。
class _DateGroup {
  _DateGroup({required this.date, required this.entries});

  final String date;
  final List<NoteEntry> entries;
}

/// 把扁平的 entries 依日期分組，保持「最新日期在前」、組內保持原順序。
/// 用 date → groupIndex 的 map 歸組（而非只比對相鄰），即使同日 entry 在 list 中
/// 不相鄰也能正確歸到同一組。
List<_DateGroup> _groupByDate(List<NoteEntry> entries) {
  final groups = <_DateGroup>[];
  final indexByDate = <String, int>{};
  for (final entry in entries) {
    final existing = indexByDate[entry.date];
    if (existing != null) {
      groups[existing].entries.add(entry);
    } else {
      indexByDate[entry.date] = groups.length;
      groups.add(_DateGroup(date: entry.date, entries: [entry]));
    }
  }
  // 同日多筆依場次排序：盤前 → 盤後 → 其他。
  // 資料層原順序是「最新發布在前」(盤後比盤前晚發布 → 盤後在前)，但閱讀直覺是
  // 盤前→盤後的時間順序，所以這裡重排，讓分段鈕「盤前在左」、預設(index 0)選盤前。
  for (final group in groups) {
    if (group.entries.length > 1) {
      group.entries.sort((a, b) => _sessionRank(a).compareTo(_sessionRank(b)));
    }
  }
  return groups;
}

/// 場次排序權重：盤前最前、盤後次之、其他（無盤前/盤後標示）墊底。
int _sessionRank(NoteEntry entry) {
  final note = entry.displayNote ?? '';
  if (note.startsWith('盤前')) return 0;
  if (note.startsWith('盤後')) return 1;
  return 2;
}

/// 內容主體：維護「選到第幾個日期 + 該日第幾個場次」的兩層 state。
///
/// 為什麼是 StatefulWidget（而非沿用 web 版的 DefaultTabController）：
/// 下拉選單 + 分段鈕都沒有現成的 index controller，選中的日期/場次就是這頁的本地
/// UI state，用最小的 setState 管理即可，不需要額外引入 controller 或 VM 欄位。
class _NoteBody extends StatefulWidget {
  const _NoteBody({required this.analyst, required this.entries});

  final Analyst analyst;
  final List<NoteEntry> entries;

  @override
  State<_NoteBody> createState() => _NoteBodyState();
}

class _NoteBodyState extends State<_NoteBody> {
  // 預設選最新日期（group 0）的第一個場次。entries 已由資料層保證「最新在前」
  int _selectedDateIndex = 0;
  int _selectedSessionIndex = 0;

  @override
  Widget build(BuildContext context) {
    final groups = _groupByDate(widget.entries);
    // clamp 防呆：資料若在 rebuild 間變動（例如重新整理後筆數變少）避免 RangeError
    final dateIndex = _selectedDateIndex.clamp(0, groups.length - 1);
    final group = groups[dateIndex];
    final sessionIndex = _selectedSessionIndex.clamp(0, group.entries.length - 1);
    final selected = group.entries[sessionIndex];

    return SafeArea(
      child: Column(
        children: [
          _NoteBanner(analyst: widget.analyst),
          _DateDropdownBar(
            groups: groups,
            selectedDateIndex: dateIndex,
            // 切換日期後場次重置回該日第一筆，避免沿用上一天的場次 index 造成錯位
            onChanged: (index) => setState(() {
              _selectedDateIndex = index;
              _selectedSessionIndex = 0;
            }),
          ),
          if (group.entries.length > 1)
            // 同日多筆：用分段鈕切盤前/盤後（短標一眼可辨），取代副標 header
            _SessionSelector(
              entries: group.entries,
              selectedIndex: sessionIndex,
              onChanged: (index) =>
                  setState(() => _selectedSessionIndex = index),
            )
          else if (selected.displayNote != null)
            // 單筆日期：沒有場次選擇問題，若有副標就直接顯示在內容頂部
            _SubtitleHeader(text: selected.displayNote!),
          const Divider(height: 1),
          Expanded(
            // ValueKey：切換日期/場次時強制重建 BlockListView，讓捲動位置歸零到頂部，
            // 而非沿用上一筆捲到一半的位置。同日多筆 date 相同，所以 key 要帶 session index
            child: BlockListView(
              key: ValueKey('${selected.date}#$sessionIndex'),
              blocks: selected.blocks,
            ),
          ),
        ],
      ),
    );
  }
}

/// 同日多筆場次切換鈕（盤前 / 盤後）。
class _SessionSelector extends StatelessWidget {
  const _SessionSelector({
    required this.entries,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<NoteEntry> entries;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<int>(
          // 場次通常只有 2 個（盤前/盤後），SegmentedButton 橫向平鋪剛好；
          // 若未來同日超過 3~4 筆再考慮換成可捲動的 chips
          segments: [
            for (var i = 0; i < entries.length; i++)
              ButtonSegment<int>(
                value: i,
                label: Text(_sessionLabel(entries[i], i)),
              ),
          ],
          selected: {selectedIndex},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
      ),
    );
  }
}

/// 從 entry 副標取「盤前 / 盤後」這類短場次標籤。
/// 副標格式通常是「盤前 · 追高警告場」，取「·」前段當短標；無副標時用「場次 N」fallback。
String _sessionLabel(NoteEntry entry, int indexInGroup) {
  final note = entry.displayNote;
  if (note == null) return '場次 ${indexInGroup + 1}';
  final head = note.split('·').first.trim();
  return head.isEmpty ? note : head;
}

/// 日期下拉選單列：放在 Banner 與內容之間的一條 bar。
/// 以「日期組」為單位（同日多筆只算一項），同日的盤前/盤後改由下方場次分段鈕區分。
class _DateDropdownBar extends StatelessWidget {
  const _DateDropdownBar({
    required this.groups,
    required this.selectedDateIndex,
    required this.onChanged,
  });

  final List<_DateGroup> groups;
  final int selectedDateIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            '日期',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            // 隱藏底線：用 Row 的 icon + label 已經足夠表達這是日期選擇器
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                isExpanded: true,
                value: selectedDateIndex,
                // value 用 group index：每個日期只出現一次，去除同日多筆造成的重複項
                items: [
                  for (var i = 0; i < groups.length; i++)
                    DropdownMenuItem<int>(
                      value: i,
                      child: Text(
                        _formatDate(groups[i].date),
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                ],
                onChanged: (index) {
                  if (index != null) onChanged(index);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 選中日期的副標 header（例如「盤前 · 追高警告場」）。
class _SubtitleHeader extends StatelessWidget {
  const _SubtitleHeader({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 把 ISO 日期轉成 "2026-05-22 週四" 好讀格式。解析失敗時回傳原字串、不讓整頁 crash。
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
    // DateTime.weekday：週一=1 ... 週日=7，減 1 對應陣列 index
    return '$iso 週${weekdayNames[dateTime.weekday - 1]}';
  } catch (_) {
    return iso;
  }
}

/// 漸層 Banner：縮圖 + 名字 + 投顧 + 返回按鈕。
///
/// 與 web 版 NotePage 的 banner 視覺一致，差別在返回行為：mobile 用 pop 回上一頁
/// （從卡片 / Banner push 進來），無法 pop 時 fallback 回首頁（例如深連結直接進本頁）。
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
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/'),
            tooltip: '返回',
          ),
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

/// 錯誤 / 找不到資料的狀態：頂部留一個可返回的 AppBar，避免使用者卡在這頁。
class _MessageState extends StatelessWidget {
  const _MessageState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/'),
            tooltip: '返回',
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(message, textAlign: TextAlign.center),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
