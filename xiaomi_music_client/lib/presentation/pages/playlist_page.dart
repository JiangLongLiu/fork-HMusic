import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/playlist_provider.dart';
import '../providers/device_provider.dart';
import 'playlist_detail_page.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/app_layout.dart';

class PlaylistPage extends ConsumerStatefulWidget {
  const PlaylistPage({super.key});

  @override
  ConsumerState<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends ConsumerState<PlaylistPage> {
  @override
  Widget build(BuildContext context) {
    final playlistState = ref.watch(playlistProvider);

    return Scaffold(
      key: const ValueKey('playlist_scaffold'),
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: _buildContent(playlistState),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: AppLayout.bottomOverlayHeight(context) + 8,
        ),
        child: FloatingActionButton(
          key: const ValueKey('playlist_fab'),
          onPressed: () => _showCreatePlaylistDialog(),
          tooltip: '新建列表',
          child: const Icon(Icons.add_rounded),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildContent(PlaylistState playlistState) {
    if (playlistState.isLoading && playlistState.playlists.isEmpty) {
      return _buildLoadingIndicator();
    }
    if (playlistState.error != null) {
      return _buildErrorState(playlistState.error!);
    }
    if (playlistState.playlists.isEmpty) {
      return _buildInitialState();
    }
    return _buildPlaylistsList(playlistState);
  }

  Widget _buildInitialState() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Center(
      key: const ValueKey('playlist_initial'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.queue_music_rounded,
            size: 80,
            color: onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          Text(
            '你的播放列表',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: onSurface.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '在这里创建和管理你的音乐收藏',
            style: TextStyle(fontSize: 16, color: onSurface.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      key: const ValueKey('playlist_loading'),
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildErrorState(String error) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Center(
      key: const ValueKey('playlist_error'),
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
              '加载列表失败',
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
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed:
                  () => ref.read(playlistProvider.notifier).refreshPlaylists(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistsList(PlaylistState playlistState) {
    return RefreshIndicator(
      key: const ValueKey('playlist_refresh'),
      onRefresh: () => ref.read(playlistProvider.notifier).refreshPlaylists(),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              AppLayout.contentBottomPadding(context),
            ),
            sliver: SliverList.builder(
              key: const ValueKey('playlist_list'),
              itemCount: playlistState.playlists.length,
              itemBuilder: (context, index) {
                final playlist = playlistState.playlists[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.queue_music_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      playlist.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      '${playlist.count ?? 0}首歌曲',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_circle_fill_rounded),
                      color: Theme.of(context).colorScheme.primary,
                      iconSize: 32,
                      onPressed: () async {
                        final did = ref.read(deviceProvider).selectedDeviceId;
                        if (did == null) {
                          if (mounted) {
                            AppSnackBar.showText(context, '请先在控制页选择播放设备');
                          }
                          return;
                        }
                        await ref
                            .read(playlistProvider.notifier)
                            .playPlaylist(
                              deviceId: did,
                              playlistName: playlist.name,
                            );
                      },
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) => PlaylistDetailPage(
                                playlistName: playlist.name,
                              ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog() {
    final controller = TextEditingController();
    bool _requestedFocus = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final onSurface = Theme.of(context).colorScheme.onSurface;
        final focusNode = FocusNode();
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final canCreate = controller.text.trim().isNotEmpty;
            // 延后聚焦，避免与底部面板动画同时触发造成卡顿
            if (!_requestedFocus) {
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                await Future.delayed(const Duration(milliseconds: 180));
                if (focusNode.canRequestFocus) {
                  FocusScope.of(context).requestFocus(focusNode);
                }
              });
              _requestedFocus = true;
            }

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: onSurface.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '新建列表',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      focusNode: focusNode,
                      autofocus: false,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: InputDecoration(
                        labelText: '列表名称',
                        hintText: '例如：我的最爱',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: onSurface.withOpacity(0.1),
                          ),
                        ),
                        filled: true,
                        fillColor: onSurface.withOpacity(0.04),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('取消'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed:
                                !canCreate
                                    ? null
                                    : () async {
                                      final name = controller.text.trim();
                                      try {
                                        await ref
                                            .read(playlistProvider.notifier)
                                            .createPlaylist(name);
                                        if (mounted) Navigator.pop(context);
                                        if (mounted) {
                                          AppSnackBar.show(
                                            context,
                                            SnackBar(
                                              content: Text('"$name" 已创建'),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) Navigator.pop(context);
                                        if (mounted) {
                                          AppSnackBar.show(
                                            context,
                                            SnackBar(
                                              content: Text('创建失败: $e'),
                                              backgroundColor: Colors.redAccent,
                                            ),
                                          );
                                        }
                                      }
                                    },
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('创建'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
