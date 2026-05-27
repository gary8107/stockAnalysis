// notes_api_service_test.dart
//
// NotesApiService 單元測試。
//
// 為什麼用 package:http/testing 的 MockClient 而不是繼承 NotesApiService：
// VM 測試是繼承 + override load()（fake 整個 service 行為），這支測試要驗證的是
// service 自己——fetch / decode / cache / 錯誤處理——所以要 mock 它的依賴 http.Client
// 才能控制 HTTP 行為。MockClient 用 closure 設定回應，比寫一個完整 Mock class 簡單。

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_analysis/services/notes_api_service.dart';

// 最小可 parse 的 NotesIndex JSON——只放足夠驗證 fromJson 走通的欄位
const _sampleIndexJson = '''
{
  "version": "1.0",
  "generated_at": "2026-05-18T00:00:00Z",
  "analysts": [
    {
      "key": "ruan-huici",
      "name": "阮蕙慈",
      "description": "大華國際投顧"
    }
  ],
  "comparisons": [
    {"date": "2026-05-15", "note": "對照日期", "blocks": []}
  ],
  "notes": []
}
''';

// http.Response(String, ...) 預設用 latin1 編碼 body 字串成 bytes，遇到中文會炸；
// 改走 Response.bytes 用 utf-8 明確編碼，也更貼近真實 HTTP server 行為——server
// 永遠送 bytes 給 client，charset 透過 Content-Type 約定
http.Response _okJson(String body) =>
    http.Response.bytes(utf8.encode(body), 200);

void main() {
  group('NotesApiService', () {
    test('200 OK：返回正確 parse 的 NotesIndex', () async {
      final service = NotesApiService(
        httpClient: MockClient(
          (request) async => _okJson(_sampleIndexJson),
        ),
      );

      final index = await service.load();

      expect(index.version, '1.0');
      expect(index.analysts, hasLength(1));
      expect(index.analysts.first.name, '阮蕙慈');
      expect(index.comparisons.first.date, '2026-05-15');
    });

    test('非 200 status：拋 NotesApiException 並帶 statusCode', () async {
      final service = NotesApiService(
        httpClient: MockClient(
          (request) async => http.Response.bytes(utf8.encode('Not Found'), 404),
        ),
      );

      await expectLater(
        service.load(),
        throwsA(
          isA<NotesApiException>()
              .having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });

    test('快取：成功後第二次 load() 不再打 HTTP', () async {
      var hits = 0;
      final service = NotesApiService(
        httpClient: MockClient((request) async {
          hits++;
          return _okJson(_sampleIndexJson);
        }),
      );

      await service.load();
      await service.load();
      await service.load();

      expect(hits, 1);
    });

    test('失敗後清快取：retry 會真的重打 HTTP', () async {
      var hits = 0;
      final service = NotesApiService(
        httpClient: MockClient((request) async {
          hits++;
          // 第一次失敗、第二次成功
          if (hits == 1) return http.Response.bytes(utf8.encode('boom'), 500);
          return _okJson(_sampleIndexJson);
        }),
      );

      // 第一次 fetch 失敗
      await expectLater(service.load(), throwsA(isA<NotesApiException>()));
      expect(hits, 1);

      // 第二次 retry：service 應該清掉 cached future 重打
      final index = await service.load();
      expect(hits, 2);
      expect(index.version, '1.0');
    });

    test('utf-8 解碼：server 回 utf-8 bytes 含中文時 parse 不亂碼', () async {
      // 用 Response.bytes 模擬真實 server 返回 utf-8 編碼 bytes 的情境
      // 驗證 service 內 utf8.decode(bodyBytes) 真的有效——某些瀏覽器若沒明確
      // 指定 charset，預設可能 fallback 成 latin1 造成中文亂碼
      final bytes = utf8.encode(_sampleIndexJson);
      final service = NotesApiService(
        httpClient: MockClient(
          (request) async => http.Response.bytes(bytes, 200),
        ),
      );

      final index = await service.load();

      expect(index.analysts.first.name, '阮蕙慈');
      expect(index.analysts.first.description, '大華國際投顧');
    });

    test('baseUrl + notesPath：HTTP 請求送到正確的 Uri', () async {
      Uri? capturedUri;
      final service = NotesApiService(
        httpClient: MockClient((request) async {
          capturedUri = request.url;
          return _okJson(_sampleIndexJson);
        }),
        baseUrl: 'https://example.com',
        notesPath: '/data/notes.json',
      );

      await service.load();

      expect(capturedUri.toString(), 'https://example.com/data/notes.json');
    });
  });
}
