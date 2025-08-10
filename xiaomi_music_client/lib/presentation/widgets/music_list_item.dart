import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/music.dart';

class MusicListItem extends StatelessWidget {
  final Music music;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final Widget? trailing;

  const MusicListItem({
    super.key,
    required this.music,
    this.onTap,
    this.onPlay,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      decoration: BoxDecoration(
        color:
            isLight
                ? Colors.black.withOpacity(0.03)
                : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isLight
                  ? Colors.black.withOpacity(0.06)
                  : Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 音乐封面
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color:
                        isLight
                            ? Colors.black.withOpacity(0.04)
                            : Colors.white.withValues(alpha: 0.1),
                  ),
                  child:
                      music.picture != null
                          ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: music.picture!,
                              fit: BoxFit.cover,
                              placeholder:
                                  (context, url) => const Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Color(0xFF667EEA),
                                            ),
                                      ),
                                    ),
                                  ),
                              errorWidget:
                                  (context, url, error) => Icon(
                                    Icons.music_note_rounded,
                                    color: onSurface.withOpacity(0.6),
                                    size: 24,
                                  ),
                            ),
                          )
                          : Icon(
                            Icons.music_note_rounded,
                            color: onSurface.withOpacity(0.6),
                            size: 24,
                          ),
                ),

                const SizedBox(width: 12),

                // 音乐信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        music.title ?? music.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: onSurface.withOpacity(0.9),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (music.artist != null) ...[
                        Text(
                          music.artist!,
                          style: TextStyle(
                            color: onSurface.withOpacity(0.7),
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (music.album != null) const SizedBox(height: 2),
                      ],
                      if (music.album != null)
                        Text(
                          music.album!,
                          style: TextStyle(
                            color: onSurface.withOpacity(0.5),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // 操作按钮区域
                if (trailing != null)
                  trailing!
                else if (onPlay != null)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF667EEA).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.play_arrow_rounded,
                        color: Color(0xFF667EEA),
                        size: 24,
                      ),
                      onPressed: onPlay,
                      tooltip: '播放',
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
