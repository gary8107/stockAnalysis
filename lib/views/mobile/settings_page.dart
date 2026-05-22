// settings_page.dart
//
// 設定 Tab：之後會放深淺色 / 字級 / 資料更新時間 / 版本 等項目。
// 第一版先放 placeholder。

import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        centerTitle: true,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.settings_outlined, size: 48),
              SizedBox(height: 16),
              Text('設定'),
              SizedBox(height: 8),
              Text(
                '功能開發中',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
