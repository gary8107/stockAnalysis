// analyst_list_page.dart
//
// 分析師 Tab：之後會放三位分析師的大卡列表，點某位 push 到該分析師個別頁。
// 第一版先放 placeholder，等對照詳細頁與導覽動作確定後一起接入。

import 'package:flutter/material.dart';

class AnalystListPage extends StatelessWidget {
  const AnalystListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分析師'),
        centerTitle: true,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 48),
              SizedBox(height: 16),
              Text('分析師列表'),
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
