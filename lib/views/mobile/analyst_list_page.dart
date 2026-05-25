// analyst_list_page.dart
//
// BottomNav「分析師」Tab 的首頁：垂直堆疊三張大卡，每張卡片用該分析師的縮圖當背景，
// 卡片下方再放一段 2~3 句的介紹文字。點擊圖片卡 push 到 /note/:key（該分析師每日筆記頁），
// 與對照 Tab 的 Banner 點擊行為一致（push 而非 go，保留 BottomNav Tab state）。
//
// 為什麼資料層沿用 HomeViewModel：
// analysts 清單已經在 NotesIndex 內隨 comparisons 一起載入，重用同一個 VM 可以
// 享受 NotesApiService 內建的 Future cache（對照 Tab 已經 load 過的話，這頁進來
// 不會再打第二次 request）。架構上與 ComparisonHomePage 對稱：頁面層套 VM + 四態 enum。
//
// 為什麼用 hardcoded bio map 而非加到 Analyst model：
// 投顧公司/節目名稱已在 Analyst.description 內，但那是「一行 metadata」，給卡片內 overlay 用；
// 這頁要的是「介紹分析師個人風格」，文字較長且只有這頁會用到。第一版直接在 view 層
// 寫死可以快速看版面，之後若要動態管理（例如進後台編輯）再擴充 Analyst 加 bio 欄位
// + tool/build_notes_json.dart 同步輸出。

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/analyst.dart';
import '../../services/notes_api_service.dart';
import '../../viewmodels/home_view_model.dart';

class AnalystListPage extends StatelessWidget {
  const AnalystListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分析師'),
        centerTitle: true,
      ),
      // 重新 new 一個 VM 而非吃 ComparisonHomePage 那一個：兩個 Tab 各自管自己的 state，
      // 但底層 NotesApiService.load() 有 cache，不會重 fetch
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
                if (viewModel.analysts.isEmpty) {
                  return const Center(child: Text('沒有分析師資料'));
                }
                return _Body(analysts: viewModel.analysts);
            }
          },
        ),
      ),
    );
  }
}

/// 每位分析師的長介紹文字。Key 對應 Analyst.key（kebab-case slug，例如 ruan-huici）。
/// 沒對應到的 key 走 fallback：顯示 Analyst.description 本身，保證不會空白。
const _analystBios = <String, String>{
  'ruan-huici':
      '大華國際投顧分析師，主持節目「金融阮實力」。'
      '擅長從盤面結構與資金流向切入，偏好提早佈局產業趨勢的中長線題材。',
  'li-shufang':
      '永誠國際投顧分析師，主持節目「股市全芳位」。'
      '節奏明快、聚焦當日強勢股與族群輪動，適合想跟上盤中熱點的投資人。',
  'chen-kunjen':
      '摩爾證券投顧分析師（外號大仁哥），主持節目「仁者無敵」。'
      '解盤風格穩健，擅長從技術面 + 籌碼面雙向印證個股位階，偏向波段操作。',
};

class _Body extends StatelessWidget {
  const _Body({required this.analysts});

  final List<Analyst> analysts;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      // 上下左右 padding 統一 16，與 ComparisonHomePage 的卡片邊距一致
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: analysts.length,
      // 用 SizedBox 而非 Divider：卡片之間視覺上分群感更強
      separatorBuilder: (context, index) => const SizedBox(height: 24),
      itemBuilder: (context, index) {
        final analyst = analysts[index];
        return _AnalystCardWithBio(
          analyst: analyst,
          bio: _analystBios[analyst.key] ?? analyst.description,
          // push 而非 go：返回鍵 pop 回分析師列表、保留捲動位置與 BottomNav state
          onTap: () => context.push('/note/${analyst.key}'),
        );
      },
    );
  }
}

/// 一張「大卡 + 卡片下方介紹文字」的組合 unit。
///
/// 點擊行為只綁在圖片卡（_AnalystImageCard 內的 InkWell）：圖片卡是 Material(elevation)，
/// ripple 能漂亮地 clip 在圓角內；介紹文字維持純說明、不可點，避免整個 Column 外包 InkWell
/// 時 ripple 被圖片卡自己的 Material 蓋住、只在文字區閃現的怪異視覺。
class _AnalystCardWithBio extends StatelessWidget {
  const _AnalystCardWithBio({
    required this.analyst,
    required this.bio,
    required this.onTap,
  });

  final Analyst analyst;
  final String bio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AnalystImageCard(analyst: analyst, onTap: onTap),
        const SizedBox(height: 12),
        // 介紹文字區塊：刻意不放在卡片內，讓圖片卡保持純圖像 + 姓名 overlay 的視覺份量，
        // 文字以 body 字級放在卡片下方，閱讀性比塞在漸層上更好
        Text(
          bio,
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.5,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 大卡：分析師縮圖鋪滿背景 + 底部漸層 + 姓名/節目 overlay。
///
/// 與 AnalystBannerCarousel 內的卡片風格刻意一致（漸層方向、白字、圓角），
/// 讓使用者在「對照 Tab Banner」與「分析師 Tab 卡片」之間有視覺連續性。
class _AnalystImageCard extends StatelessWidget {
  const _AnalystImageCard({required this.analyst, required this.onTap});

  final Analyst analyst;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // AspectRatio 16:9：手機直向時換算大約 210px 高，三張卡 + 介紹 + Tab bar 不會
    // 超過一個首屏，使用者只需要小幅捲動就能瀏覽完三位分析師
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Material(
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              analyst.thumbnail,
              fit: BoxFit.cover,
              // 縮圖檔損毀 / 路徑誤植時不讓整頁 crash，給一個友善 fallback
              errorBuilder: (context, error, stackTrace) => ColoredBox(
                color: colors.surfaceContainerHigh,
                child: const Center(
                  child: Icon(Icons.broken_image_outlined, size: 48),
                ),
              ),
            ),
            // 底部漸層遮罩：讓白字在任何縮圖背景上都能看清楚
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.65),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              // Row + 右側 chevron：給使用者「這張卡可以點進去」的視覺暗示（affordance），
              // 姓名/節目用 Expanded 佔滿剩餘寬度、過長時 ellipsis，不會把 chevron 擠出畫面
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          analyst.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          analyst.description,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ],
              ),
            ),
            // InkWell 疊在最上層（Positioned.fill + 透明 Material）：讓點擊 ripple 顯示在
            // 不透明縮圖「之上」。若把 InkWell 包在 Stack 底層，splash 會被 Image.asset
            // 蓋住、看不到水波紋。透明 Material 不影響下方圖層的視覺。
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap),
              ),
            ),
          ],
        ),
      ),
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
          Text('載入分析師資料失敗', style: Theme.of(context).textTheme.titleMedium),
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
