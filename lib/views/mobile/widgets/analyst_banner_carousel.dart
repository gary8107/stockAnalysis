// analyst_banner_carousel.dart
//
// 三位分析師圖片輪播 Banner，給對照首頁上方顯示用。
//
// 設計取捨：
// - 自製 PageView + Timer 而非引入 carousel_slider，依賴更少、第一版需求簡單
// - 自動切換 4 秒一張：手機使用者滑動瀏覽時，這節奏不會干擾閱讀又能讓 3 張卡都被看到
// - 使用者手動滑動時，Timer 不暫停（單純切到下一張接著繼續自動播放，因為節奏夠慢不會打架）
// - 點擊動作目前是 placeholder（onTap callback 傳上去），等 AnalystListPage 接通後再改成 navigate

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/analyst.dart';

class AnalystBannerCarousel extends StatefulWidget {
  const AnalystBannerCarousel({
    super.key,
    required this.analysts,
    required this.onAnalystTap,
    this.height = 200,
    this.autoPlayInterval = const Duration(seconds: 4),
  });

  final List<Analyst> analysts;
  final ValueChanged<Analyst> onAnalystTap;
  final double height;
  final Duration autoPlayInterval;

  @override
  State<AnalystBannerCarousel> createState() => _AnalystBannerCarouselState();
}

class _AnalystBannerCarouselState extends State<AnalystBannerCarousel> {
  // initialPage 給一個遠離 0 的數字，讓使用者可以無限往左滑（不會撞牆）
  // PageView.builder + itemBuilder 用 mod 取餘數對應到實際 3 位分析師
  static const _initialPage = 1000;

  late final PageController _pageController;
  Timer? _autoPlayTimer;
  int _currentPage = _initialPage;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _initialPage);
    _startAutoPlay();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(widget.autoPlayInterval, (_) {
      if (!_pageController.hasClients) return;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.analysts.isEmpty) {
      return SizedBox(height: widget.height);
    }

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (page) => setState(() => _currentPage = page),
            itemBuilder: (context, index) {
              final analyst = widget.analysts[index % widget.analysts.length];
              return _AnalystBannerCard(
                analyst: analyst,
                onTap: () => widget.onAnalystTap(analyst),
              );
            },
          ),
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: _DotsIndicator(
              count: widget.analysts.length,
              currentIndex: _currentPage % widget.analysts.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalystBannerCard extends StatelessWidget {
  const _AnalystBannerCard({required this.analyst, required this.onTap});

  final Analyst analyst;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                analyst.thumbnail,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: colors.surfaceContainerHigh,
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined, size: 48),
                  ),
                ),
              ),
              // 底部漸層遮罩：讓白色文字在任何縮圖上都能看清楚
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
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
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({required this.count, required this.currentIndex});

  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white
                : Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
