// markdown_loader.dart
//
// 負責從 Flutter assets 載入 markdown 文字內容。
// 為什麼抽成獨立 service：未來想換成「從 GitHub raw 拉」或「動態 fetch」時，
// 只要換這個 class 的實作，view / viewmodel 都不用動——對應 iOS 的 Repository pattern。

import 'package:flutter/services.dart' show rootBundle;

class MarkdownLoader {
  /// 從 asset 載入文字內容。
  ///
  /// 為什麼用 rootBundle 而不是 dart:io File：
  /// Flutter Web 沒有 File API，跨平台統一走 AssetBundle 才能 web / iOS / macOS / Android 都跑。
  Future<String> load(String assetPath) {
    return rootBundle.loadString(assetPath);
  }
}
