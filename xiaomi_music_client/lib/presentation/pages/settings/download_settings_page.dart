import 'package:flutter/material.dart';
import '../../widgets/app_snackbar.dart';

class DownloadSettingsPage extends StatefulWidget {
  const DownloadSettingsPage({super.key});

  @override
  State<DownloadSettingsPage> createState() => _DownloadSettingsPageState();
}

class _DownloadSettingsPageState extends State<DownloadSettingsPage> {
  bool autoDownload = false;
  String quality = 'standard';
  final TextEditingController proxyController = TextEditingController();

  @override
  void dispose() {
    proxyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar: AppBar(title: const Text('下载设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('自动下载'),
            subtitle: const Text('当本地找不到歌曲时自动尝试网络下载'),
            value: autoDownload,
            onChanged: (v) => setState(() => autoDownload = v),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('音质'),
            subtitle: Text(switch (quality) {
              'standard' => '标准音质',
              'high' => '高音质',
              'super' => '超高音质',
              _ => quality,
            }, style: TextStyle(color: onSurface.withOpacity(0.7))),
            trailing: DropdownButton<String>(
              value: quality,
              items: const [
                DropdownMenuItem(value: 'standard', child: Text('标准')),
                DropdownMenuItem(value: 'high', child: Text('高')),
                DropdownMenuItem(value: 'super', child: Text('超高')),
              ],
              onChanged: (v) => setState(() => quality = v ?? 'standard'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: proxyController,
            decoration: const InputDecoration(
              labelText: '代理（可选）',
              hintText: 'http://proxy.example.com:8080 或 socks5://host:1080',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              // 仅 UI：暂存到内存并提示。后续可接入后端 /setsetting
              AppSnackBar.showText(context, '设置已保存（本地暂存，未调用后端）');
            },
            icon: const Icon(Icons.save_rounded),
            label: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
