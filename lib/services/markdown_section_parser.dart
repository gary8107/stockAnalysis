// markdown_section_parser.dart
//
// 把一份 markdown 字串按 `## YYYY-MM-DD（...）` H2 標題拆成多個區段。
// 用途：對照檔的「日期 Tab」、個別分析師檔的「日期 Tab」。
//
// 為什麼放 services 而非 utils：未來如果支援不同 H2 格式（例如英文日期），
// 換實作只動這個 class，view / model 不用變——對應 iOS 的 Parser pattern。

class MarkdownSection {
  /// 區段日期，例如 "2026-05-12"
  final String date;

  /// H2 括號後綴的內容，例如 "影片日期"、"對照日期"、"盤前 · 追高警告場"。
  /// 沒有括號則為 null。
  final String? note;

  /// H2 完整標題行（含原始括號，例如 `## 2026-05-12（影片日期）`）
  final String heading;

  /// 該區段完整 markdown 內容（從 H2 標題到下一個 H2 之前，含原 H2 標題）
  final String content;

  const MarkdownSection({
    required this.date,
    required this.note,
    required this.heading,
    required this.content,
  });

  // 「影片日期 / 對照日期 / 筆記日期」這類泛用標籤對使用者不額外有意義，
  // UI 直接忽略；保留「盤前/盤後/特殊場次」這類有區分價值的副標。
  static const _genericLabels = {'影片日期', '對照日期', '筆記日期'};

  /// UI 顯示用副標——泛用標籤回 null（只顯示日期）；其他回原副標
  String? get displayNote {
    final n = note;
    if (n == null) return null;
    if (_genericLabels.contains(n)) return null;
    return n;
  }
}

class MarkdownSectionParser {
  // 偵測 `## YYYY-MM-DD` 開頭的 H2 標題，並抓出可選的「（...）」括號內容
  //
  // 兼容半形 `()` 與全形 `（）`；group(1) = 日期，group(2) = 括號內文字（可選）
  // multiLine: true → ^ 對應每行開頭而非整字串開頭
  // 嚴格用 \d{4}-\d{2}-\d{2} 避免抓到其他 H2 標題（例如 `## 一、大盤分析`）
  static final _h2DateRegex = RegExp(
    r'^## (\d{4}-\d{2}-\d{2})(?:\s*[（(]([^）)]+)[）)])?',
    multiLine: true,
  );

  /// 把 markdown 拆成日期區段。
  /// 區段順序保留原 markdown 順序——筆記檔約定「最新在上」，所以 list 第一筆也是最新日期。
  List<MarkdownSection> parse(String markdown) {
    final matches = _h2DateRegex.allMatches(markdown).toList();
    if (matches.isEmpty) return const [];

    final sections = <MarkdownSection>[];
    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final date = match.group(1)!;
      final noteRaw = match.group(2)?.trim();
      final note = (noteRaw != null && noteRaw.isNotEmpty) ? noteRaw : null;
      final start = match.start;
      // 該區段內容從這個 H2 開始，到下一個 H2 之前（或檔尾）
      final end =
          (i + 1 < matches.length) ? matches[i + 1].start : markdown.length;
      final content = markdown.substring(start, end).trimRight();

      // heading 是該 H2 那整行（給 UI 顯示完整 metadata 用）
      final firstNewline = markdown.indexOf('\n', start);
      final headingEnd = firstNewline == -1 ? markdown.length : firstNewline;
      final heading = markdown.substring(start, headingEnd);

      sections.add(
        MarkdownSection(
          date: date,
          note: note,
          heading: heading,
          content: content,
        ),
      );
    }
    return sections;
  }
}
