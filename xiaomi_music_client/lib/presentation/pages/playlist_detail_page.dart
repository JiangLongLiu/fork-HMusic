import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/playlist_provider.dart';
import '../providers/playback_provider.dart';
import '../providers/device_provider.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/app_layout.dart';

class PlaylistDetailPage extends ConsumerStatefulWidget {
  final String playlistName;
  const PlaylistDetailPage({super.key, required this.playlistName});

  @override
  ConsumerState<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends ConsumerState<PlaylistDetailPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(playlistProvider.notifier)
          .loadPlaylistMusics(widget.playlistName);
    });
  }

  Future<void> _playWholePlaylist() async {
    final did = ref.read(deviceProvider).selectedDeviceId;
    if (did == null) {
      if (mounted) {
        AppSnackBar.showText(context, '请先在控制页选择播放设备');
      }
      return;
    }
    await ref
        .read(playlistProvider.notifier)
        .playPlaylist(deviceId: did, playlistName: widget.playlistName);
  }

  Future<void> _playSingle(String musicName) async {
    final did = ref.read(deviceProvider).selectedDeviceId;
    if (did == null) {
      if (mounted) {
        AppSnackBar.showText(context, '请先在控制页选择播放设备');
      }
      return;
    }
    await ref
        .read(playbackProvider.notifier)
        .playMusic(deviceId: did, musicName: musicName);
  }

  Future<void> _showPlaylistDownloadDialog() async {
    final urlController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('下载播放列表：${widget.playlistName}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('请输入要下载的网络播放列表URL（可选）：'),
                const SizedBox(height: 12),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    hintText: '例如：https://example.com/playlist.m3u',
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
            .read(playlistProvider.notifier)
            .downloadPlaylist(
              widget.playlistName,
              url: result.isEmpty ? null : result,
            );
        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text('已提交下载任务：${widget.playlistName}'),
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playlistProvider);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    final musics =
        state.currentPlaylist == widget.playlistName
            ? state.currentPlaylistMusics
            : <String>[];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(widget.playlistName),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_circle_fill_rounded),
            onPressed: _playWholePlaylist,
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'download':
                  await _showPlaylistDownloadDialog();
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'download',
                    child: Text('整表下载到本地'),
                  ),
                ],
          ),
        ],
      ),
      body:
          state.isLoading && musics.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : musics.isEmpty
              ? Center(
                child: Text(
                  '此列表暂无歌曲',
                  style: TextStyle(color: onSurface.withOpacity(0.6)),
                ),
              )
              : ListView.builder(
                padding: EdgeInsets.only(
                  bottom: AppLayout.contentBottomPadding(context),
                  top: 12,
                ),
                itemCount: musics.length,
                itemBuilder: (context, index) {
                  final musicName = musics[index];
                  return ListTile(
                    leading: const Icon(Icons.music_note_rounded),
                    title: Text(musicName),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_arrow_rounded),
                      onPressed: () => _playSingle(musicName),
                    ),
                    onTap: () => _playSingle(musicName),
                  );
                },
              ),
    );
  }
}
