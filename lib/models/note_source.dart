// note_source.dart
//
// 描述一份筆記來源（分析師檔案或對照檔）。
// 為什麼用 sealed-ish 的常數清單而不是動態掃描資料夾：
// Flutter assets 在 build 時就被打包進去，runtime 沒有「列出目錄」的 API，
// 所以筆記來源必須在編譯期明確寫死。

enum NoteKind {
  /// 個別分析師的筆記檔
  analyst,

  /// 跨分析師對照檔
  comparison,
}

class NoteSource {
  /// 顯示在卡片上的標題（中文姓名 / 對照名稱）
  final String name;

  /// 卡片副標題：投顧公司或檔案性質的一行描述
  final String description;

  /// pubspec.yaml 註冊的 asset 路徑，runtime 用 rootBundle 載入
  final String assetPath;

  /// 卡片縮圖：個別分析師用 YouTube 節目縮圖、對照檔用 cartoon placeholder
  final String thumbnailAsset;

  /// 個別分析師 vs. 對照檔——之後 UI 樣式會分流（例如卡片顏色、icon）
  final NoteKind kind;

  const NoteSource({
    required this.name,
    required this.description,
    required this.assetPath,
    required this.thumbnailAsset,
    required this.kind,
  });

  /// 寫死的來源清單。新增分析師時改這裡 + 更新 sync_notes.sh 即可
  static const List<NoteSource> all = [
    NoteSource(
      name: '阮蕙慈',
      description: '大華國際投顧 · 金融阮實力',
      assetPath: 'assets/notes/阮蕙慈分析.md',
      thumbnailAsset: 'assets/thumbnails/ruan-huici.jpg',
      kind: NoteKind.analyst,
    ),
    NoteSource(
      name: '李蜀芳',
      description: '永誠國際投顧 · 股市全芳位',
      assetPath: 'assets/notes/李蜀芳分析.md',
      thumbnailAsset: 'assets/thumbnails/li-shufang.jpg',
      kind: NoteKind.analyst,
    ),
    NoteSource(
      name: '陳昆仁(大仁哥)',
      description: '摩爾證券投顧 · 仁者無敵',
      assetPath: 'assets/notes/陳昆仁分析.md',
      thumbnailAsset: 'assets/thumbnails/chen-kunjen.jpg',
      kind: NoteKind.analyst,
    ),
    NoteSource(
      name: '跨分析師對照重點',
      description: '同日多位分析師觀點比對',
      assetPath: 'assets/notes/分析師對照重點.md',
      thumbnailAsset: 'assets/thumbnails/comparison.png',
      kind: NoteKind.comparison,
    ),
  ];
}
