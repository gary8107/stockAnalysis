// notes_api_service.dart
//
// 從 /api/notes.json 拉結構化筆記資料。
//
// 為什麼存在：取代 Phase 2 的 MarkdownLoader + MarkdownSectionParser 組合。
// Build-time 把 markdown parse 成結構化 JSON（tool/build_notes_json.dart），
// runtime 只剩「fetch + decode」這件單純的事。
//
// 為什麼包 Future cache 而非每次 load() 都重打：
// 整個 app 起手就會有 HomeViewModel + NoteViewModel（將來還有 SearchViewModel）
// 都 call load()，沒快取就會 fetch N 次。快取 Future（非 result）讓 concurrent
// load 共享同一個 in-flight request；fetch 失敗時清快取讓使用者 retry 能重打。
//
// 為什麼用 baseUrl 預設空字串：
// web 同 origin fetch `/api/notes.json` 不需要 absolute URL；
// 手機 App 將來注入 `https://gary8107.github.io/stockAnalysis/`，
// 同一個 service 兩平台共用。

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/notes_index.dart';

class NotesApiService {
  NotesApiService({
    http.Client? httpClient,
    this.baseUrl = '',
    this.notesPath = '/api/notes.json',
  }) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// 預設空字串走相對路徑（web 同 origin）；手機 App 注入 absolute URL，
  /// 例如 'https://gary8107.github.io/stockAnalysis'
  final String baseUrl;

  /// API 路徑——抽出來讓未來改 endpoint 不用動 caller
  final String notesPath;

  Future<NotesIndex>? _cached;

  /// 載入整份 NotesIndex。多次呼叫只會 fetch 一次（失敗會清快取讓 retry 能重打）。
  Future<NotesIndex> load() async {
    final cached = _cached;
    if (cached != null) return cached;

    final future = _fetch();
    _cached = future;
    try {
      return await future;
    } catch (_) {
      // fetch 失敗清掉快取，下次 caller retry 能真的重打 request
      // 不在這裡轉換 error 型別，讓 caller 看到原始 http/format 例外
      _cached = null;
      rethrow;
    }
  }

  Future<NotesIndex> _fetch() async {
    final uri = Uri.parse('$baseUrl$notesPath');
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw NotesApiException(
        'Failed to load notes: HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
    // utf8.decode 明確指定編碼——中文內容 default decoder 在某些瀏覽器會走 latin1 噴亂碼
    final body = utf8.decode(response.bodyBytes);
    final json = jsonDecode(body) as Map<String, dynamic>;
    return NotesIndex.fromJson(json);
  }
}

/// API 載入錯誤——讓 caller 用 type 判斷而非靠 message 字串比對
class NotesApiException implements Exception {
  const NotesApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'NotesApiException: $message';
}
