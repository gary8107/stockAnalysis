// analyst_thumbnails.dart
//
// 分析師縮圖 asset 對映（UI 呈現層）。
//
// 為什麼放這裡、不再經由 notes.json：
// 分析師是固定的四位、不是從筆記動態產生的，縮圖屬於 App 的視覺資產、
// 與筆記資料（notes.json 由 tool/build_notes_json.dart 產生）無關。把對映
// 留在 App 端，notes.json 就只負責「筆記內容」這件事，資料層職責更乾淨。
//
// key = Analyst.key（kebab-case slug）。換圖 / 新增分析師只要改這張表
// 並把對應檔放進 assets/thumbnails/ 即可。

const _thumbnailByAnalystKey = <String, String>{
  'ruan-huici': 'assets/thumbnails/rhc_0.jpg',
  'li-shufang': 'assets/thumbnails/lsf_0.jpg',
  'chen-kunjen': 'assets/thumbnails/ckj_0.jpg',
  'cai-zhenghua': 'assets/thumbnails/cai-zhenghua.jpg',
};

const _bannerByAnalystKey = <String, String>{
  'ruan-huici': 'assets/thumbnails/rhc_banner.jpg',
  'li-shufang': 'assets/thumbnails/lsf_banner.jpg',
  'chen-kunjen': 'assets/thumbnails/ckj_banner.jpg',
  'cai-zhenghua': 'assets/thumbnails/tzh_banner.jpg',
};

/// 依分析師 slug 取縮圖 asset path。
///
/// 找不到對映時回傳對照用的 `comparison.png` 當佔位——理論上四位固定分析師
/// 都在表內、不會走到 fallback；各 view 的 `Image.asset` 也都還有 errorBuilder
/// 雙保險，缺檔時顯示 broken_image 而非整頁 crash。
String analystThumbnail(String analystKey) =>
    _thumbnailByAnalystKey[analystKey] ?? 'assets/thumbnails/comparison.png';

String analystBanner(String analystKey) =>
    _bannerByAnalystKey[analystKey] ??
    'assets/thumbnails/comparison_banner.png';
