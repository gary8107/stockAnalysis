// analyst.dart
//
// 一位分析師的 metadata。從 notes.json 的 analysts 陣列載入，
// 取代原本 hardcode 在 lib/models/note_source.dart 的硬編 list。
//
// 為什麼用 slug key 而不是 name 當 FK：
// AnalystNote.analystKey 會用這個 key 對映，name 是中文且可能變動
// （例如「陳昆仁」可能改成「陳昆仁(大仁哥)」），slug 穩定。

class Analyst {
  const Analyst({
    required this.key,
    required this.name,
    required this.description,
    required this.thumbnail,
  });

  /// 唯一識別 slug（kebab-case 英文），例如 "ruan-huici"
  final String key;

  /// 中文姓名，顯示用
  final String name;

  /// 投顧公司 / 節目 一行描述
  final String description;

  /// 縮圖 asset path，例如 "assets/thumbnails/ruan-huici.jpg"
  final String thumbnail;

  factory Analyst.fromJson(Map<String, dynamic> json) => Analyst(
        key: json['key'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        thumbnail: json['thumbnail'] as String,
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'name': name,
        'description': description,
        'thumbnail': thumbnail,
      };
}
