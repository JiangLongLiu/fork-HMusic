import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/music_search_provider.dart';
import '../providers/playback_provider.dart';
import '../providers/device_provider.dart';
import '../providers/music_library_provider.dart';
import '../widgets/music_list_item.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/app_layout.dart';

class MusicSearchPage extends ConsumerStatefulWidget {
  const MusicSearchPage({super.key});

  @override
  ConsumerState<MusicSearchPage> createState() => _MusicSearchPageState();
}

class _MusicSearchPageState extends ConsumerState<MusicSearchPage> {
  Future<void> _showMusicDownloadDialog(String musicName) async {
    final urlController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('下载音乐：$musicName'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('请输入要下载的网络音乐URL（可选）：'),
                const SizedBox(height: 12),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    hintText: '例如：https://example.com/music.mp3',
                    labelText: 'URL（可留空）',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed:
                    () => Navigator.pop(context, urlController.text.trim()),
                child: const Text('下载'),
              ),
            ],
          ),
    );

    if (result != null) {
      try {
        await ref
            .read(musicLibraryProvider.notifier)
            .downloadOneMusic(musicName, url: result.isEmpty ? null : result);
        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text('已提交下载任务：$musicName'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(content: Text('下载失败：$e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _playMusic(String musicName) async {
    final selectedDid = ref.read(deviceProvider).selectedDeviceId;
    if (selectedDid == null) {
      if (mounted) {
        AppSnackBar.showText(context, '请先选择一个播放设备');
      }
      return;
    }

    try {
      await ref
          .read(playbackProvider.notifier)
          .playMusic(deviceId: selectedDid, musicName: musicName);
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('播放失败: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(musicSearchProvider);

    return Scaffold(
      key: const ValueKey('music_search_scaffold'),
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: _buildContent(searchState),
      ),
    );
  }

  Widget _buildContent(MusicSearchState searchState) {
    if (searchState.isLoading) {
      return _buildLoadingIndicator();
    }
    if (searchState.error != null) {
      return _buildErrorState(searchState.error!);
    }
    if (searchState.searchResults.isNotEmpty) {
      return _buildResultsList(searchState.searchResults);
    }
    return _buildInitialState();
  }

  Widget _buildInitialState() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Center(
      key: const ValueKey('search_initial'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_rounded,
            size: 80,
            color: onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          Text(
            '开始搜索音乐',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: onSurface.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '输入歌曲、艺术家或专辑名称',
            style: TextStyle(fontSize: 16, color: onSurface.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      key: const ValueKey('search_loading'),
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildErrorState(String error) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Center(
      key: const ValueKey('search_error'),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 60,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 20),
            Text(
              '哦豁，出错了',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              error,
              style: TextStyle(fontSize: 15, color: onSurface.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList(List<dynamic> results) {
    return ListView.builder(
      key: const ValueKey('search_results'),
      padding: EdgeInsets.only(
        bottom: AppLayout.contentBottomPadding(context),
        top: 20,
      ),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final music = results[index];
        return MusicListItem(
          music: music,
          onTap: () => _playMusic(music.name),
          onPlay: () => _playMusic(music.name),
          trailing: PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.more_vert_rounded,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                size: 18,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) async {
              switch (value) {
                case 'play':
                  _playMusic(music.name);
                  break;
                case 'download':
                  await _showMusicDownloadDialog(music.name);
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'play',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 12),
                        const Text('播放'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'download',
                    child: Row(
                      children: [
                        Icon(
                          Icons.download_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        const Text('下载到本地'),
                      ],
                    ),
                  ),
                ],
          ),
        );
      },
    );
  }
}
