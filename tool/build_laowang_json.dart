// build_laowang_json.dart
//
// 把 assets/notes/王倚隆分析.md（浦惠投顧老王／PressPlay 付費專欄）轉成
// web/api/laowang.json —— 一支「獨立的」API 檔，格式為老王量身、與 notes.json 無關。
//
// 設計原則（為什麼這樣設計）：
// - 老王是 PressPlay「付費訂閱」來源，與 4 位 YouTube 公開影片分析師性質不同，
//   先前已決定獨立檔、不併入對照；API 層同樣維持隔離，web/App 打獨立 endpoint。
// - 格式「不」沿用 notes.json 的 block/table schema。理由：老王內文圖文混排、重點是
//   「能完整顯示」。所以每篇文章直接保留「完整 markdown 原文」(markdown 欄位)，前端
//   render 該欄位即可 100% 還原內容、絕不漏字；另外附結構化欄位(title/published_at/
//   核心定調/依 H3 切好的 sections)，前端想做分段排版時可選用。
// - 純 dart:io，不 import 任何 lib/ model（真正獨立、零耦合，老王 md 改格式也不會牽動 App 編譯）。
//
// 用法：
//   dart run tool/build_laowang_json.dart      # 從 repo 根目錄跑
//
// 輸出：web/api/laowang.json（提交進 git；flutter build web 會自動帶上）

import 'dart:convert';
import 'dart:io';

const _sourceFile = 'assets/notes/王倚隆分析.md';
const _outputPath = 'web/api/laowang.json';

void main(List<String> args) {
  final stopwatch = Stopwatch()..start();

  final file = File(_sourceFile);
  if (!file.existsSync()) {
    stderr.writeln('error: $_sourceFile not found');
    exitCode = 1;
    return;
  }

  final markdown = file.readAsStringSync();
  final articles = _splitArticles(markdown).map(_buildArticle).toList();

  final payload = <String, dynamic>{
    'source': 'PressPlay · 浦惠投顧 王倚隆（老王）每日報告（付費訂閱）',
    'analyst': <String, dynamic>{
      'name': '王倚隆（老王）',
      'firm': '浦惠投顧',
      'platform': 'PressPlay 老王每日報告',
      'paid': true,
    },
    // 重點濃縮、非逐字重製；個股股號為對照推測，使用前請以實際畫面確認
    'disclaimer': '本內容為個人學習用重點濃縮（非原文逐字重製），所有個股皆非投資建議，'
        '投資人應獨立判斷、自負投資風險。',
    'generated_at': DateTime.now().toUtc().toIso8601String(),
    'count': articles.length,
    // 最新在最前（沿用 md 的倒序）
    'articles': articles,
  };

  final output = File(_outputPath);
  output.parent.createSync(recursive: true);
  // indented JSON 讓 git diff 看得到變化
  final encoder = const JsonEncoder.withIndent('  ');
  output.writeAsStringSync(encoder.convert(payload));

  stopwatch.stop();
  stdout.writeln(
    'Wrote ${output.path} '
    '(${_humanSize(output.lengthSync())}) '
    '— ${articles.length} 篇老王文章 '
    'in ${stopwatch.elapsedMilliseconds}ms',
  );
}

// ---------- 以 H2 日期標題切成「每篇文章」 ----------

class _Article {
  const _Article({required this.date, required this.subtitle, required this.body});
  final String date; // YYYY-MM-DD
  final String? subtitle; // H2 括號內副標（含「文章日期 · 標題」），可能為 null
  final String body; // H2 標題行的下一行起到下一個 H2 之前（不含 H2 本身）
}

// `## YYYY-MM-DD（...）`：group(1)=日期、group(2)=括號內副標（兼容全/半形括號）
final _h2DateRegex = RegExp(
  r'^## (\d{4}-\d{2}-\d{2})(?:\s*[（(]([^）)]+)[）)])?',
  multiLine: true,
);

List<_Article> _splitArticles(String markdown) {
  final matches = _h2DateRegex.allMatches(markdown).toList();
  final articles = <_Article>[];
  for (var i = 0; i < matches.length; i++) {
    final match = matches[i];
    final date = match.group(1)!;
    final rawSub = match.group(2)?.trim();
    final subtitle = (rawSub != null && rawSub.isNotEmpty) ? rawSub : null;

    final firstNewline = markdown.indexOf('\n', match.start);
    final bodyStart = firstNewline == -1 ? markdown.length : firstNewline + 1;
    final end = (i + 1 < matches.length) ? matches[i + 1].start : markdown.length;
    final body = markdown.substring(bodyStart, end).trim();

    articles.add(_Article(date: date, subtitle: subtitle, body: body));
  }
  return articles;
}

// ---------- 把一篇文章拆成結構化欄位 ----------

Map<String, dynamic> _buildArticle(_Article article) {
  final body = article.body;

  // 標題：優先取內文的「- **文章標題**：xxx」；否則用 H2 副標去掉「文章日期 · 」前綴
  final title = _extractField(body, '文章標題') ??
      _stripDatePrefix(article.subtitle) ??
      '老王 ${article.date} 盤勢報告';
  final publishedAt = _extractField(body, '發布時間');
  final articleType = _extractField(body, '文章性質');

  // intro = 第一個 H3（###）之前的內容（含 metadata bullets 與「核心定調」）
  final firstH3 = RegExp(r'^### ', multiLine: true).firstMatch(body);
  final introEnd = firstH3?.start ?? body.length;
  final intro = body.substring(0, introEnd).trim();

  return <String, dynamic>{
    'date': article.date,
    'title': title,
    if (publishedAt != null) 'published_at': publishedAt,
    if (articleType != null) 'article_type': articleType,
    // intro：metadata 與核心定調區（H3 之前），方便前端做「摘要卡」
    'intro_markdown': intro,
    // sections：依 H3 切好，方便分段排版
    'sections': _splitSections(body),
    // markdown：該篇「完整原文」—— 前端 render 這個就保證完整顯示、絕不漏內容
    'markdown': body,
  };
}

// 依 `### ` H3 標題把 body 切成 [{heading, markdown}]（H3 之前的內容不計入 sections，放在 intro）
List<Map<String, dynamic>> _splitSections(String body) {
  final matches = RegExp(r'^### (.+)$', multiLine: true).allMatches(body).toList();
  final sections = <Map<String, dynamic>>[];
  for (var i = 0; i < matches.length; i++) {
    final match = matches[i];
    final heading = match.group(1)!.trim();
    final firstNewline = body.indexOf('\n', match.start);
    final contentStart = firstNewline == -1 ? body.length : firstNewline + 1;
    final end = (i + 1 < matches.length) ? matches[i + 1].start : body.length;
    final content = body.substring(contentStart, end).trim();
    sections.add(<String, dynamic>{'heading': heading, 'markdown': content});
  }
  return sections;
}

// 從內文抓「- **<label>**：<value>」這類 metadata 行的值（抓到第一個就回傳）
String? _extractField(String body, String label) {
  final regex = RegExp('^[-*]\\s*\\*\\*$label\\*\\*[：:]\\s*(.+)\$', multiLine: true);
  final match = regex.firstMatch(body);
  if (match == null) return null;
  final value = match.group(1)!.trim();
  return value.isEmpty ? null : value;
}

// 去掉 H2 副標的「文章日期 · 」前綴，只留標題本身
String? _stripDatePrefix(String? subtitle) {
  if (subtitle == null) return null;
  final idx = subtitle.indexOf('·');
  if (idx == -1) return subtitle.trim();
  return subtitle.substring(idx + 1).trim();
}

// ---------- Helpers ----------

String _humanSize(int bytes) {
  if (bytes < 1024) return '${bytes}B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
}
