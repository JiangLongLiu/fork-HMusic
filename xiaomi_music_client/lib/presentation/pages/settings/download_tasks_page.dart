import 'package:flutter/material.dart';

class DownloadTasksPage extends StatelessWidget {
  const DownloadTasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar: AppBar(title: const Text('下载任务')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: onSurface.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: onSurface.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '暂无下载任务',
                  style: TextStyle(
                    color: onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '当你在曲库、列表或搜索中触发“下载到本地”后，任务会显示在这里。',
                  style: TextStyle(color: onSurface.withOpacity(0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

