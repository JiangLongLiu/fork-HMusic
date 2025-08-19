import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/dio_provider.dart';

class DownloadTasksPage extends ConsumerStatefulWidget {
  const DownloadTasksPage({super.key});

  @override
  ConsumerState<DownloadTasksPage> createState() => _DownloadTasksPageState();
}

class _DownloadTasksPageState extends ConsumerState<DownloadTasksPage> {
  String _log = '';
  bool _loading = false;

  Future<void> _load() async {
    final api = ref.read(apiServiceProvider);
    if (api == null) return;
    setState(() => _loading = true);
    try {
      final text = await api.getDownloadLog();
      setState(() => _log = text);
    } catch (_) {
      setState(() => _log = '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar: AppBar(title: const Text('下载任务')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
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
                Row(
                  children: [
                    Text(
                      '下载任务',
                      style: TextStyle(
                        color: onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (_loading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.refresh, size: 18),
                        onPressed: _load,
                        tooltip: '刷新',
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_log.isEmpty)
                  Text(
                    '暂无下载记录。\n\n'
                    '提示：\n- 在搜索结果里选择“下载到服务器”可创建任务\n- 在设置菜单的“从链接下载”可提交单曲/整表任务',
                    style: TextStyle(color: onSurface.withOpacity(0.7)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: onSurface.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: onSurface.withOpacity(0.06)),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        _log,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: onSurface.withOpacity(0.85),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ));
  }
}








