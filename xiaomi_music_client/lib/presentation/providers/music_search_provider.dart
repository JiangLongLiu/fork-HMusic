import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/music.dart';
import '../../data/models/online_music_result.dart';
import '../../data/services/unified_api_service.dart';
import '../../data/services/youtube_proxy_service.dart';
import 'js_source_provider.dart';
import 'source_settings_provider.dart';
import 'dio_provider.dart';
import '../../data/adapters/search_adapter.dart';

class MusicSearchState {
  final List<Music> searchResults;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final List<OnlineMusicResult> onlineResults;

  const MusicSearchState({
    this.searchResults = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.onlineResults = const [],
  });

  MusicSearchState copyWith({
    List<Music>? searchResults,
    bool? isLoading,
    String? error,
    String? searchQuery,
    List<OnlineMusicResult>? onlineResults,
  }) {
    return MusicSearchState(
      searchResults: searchResults ?? this.searchResults,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      onlineResults: onlineResults ?? this.onlineResults,
    );
  }
}

class MusicSearchNotifier extends StateNotifier<MusicSearchState> {
  final Ref ref;

  MusicSearchNotifier(this.ref) : super(const MusicSearchState());

  Future<void> searchMusic(String query) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(searchResults: [], searchQuery: '', error: null);
      return;
    }

    final apiService = ref.read(apiServiceProvider);
    if (apiService == null) return;

    try {
      state = state.copyWith(isLoading: true, searchQuery: query, error: null);

      final results = await apiService.searchMusic(query);
      final musicList = SearchAdapter.parse(results);

      state = state.copyWith(
        searchResults: musicList,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        searchResults: [],
      );
    }
  }

  // 第三方在线搜索
  Future<void> searchOnline(String query) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(onlineResults: [], searchQuery: '', error: null);
      return;
    }

    final apiService = ref.read(apiServiceProvider);
    if (apiService == null) return;

    try {
      // ignore: avoid_print
      print('🔍 searchOnline: start query="$query"');
      state = state.copyWith(isLoading: true, searchQuery: query, error: null);
      final settings = ref.read(sourceSettingsProvider);

      // 详细的设置状态调试
      print('🔧 [MusicSearch] JS音源启用: ${settings.enabled}');
      print('🔧 [MusicSearch] 使用JS搜索: ${settings.useJsForSearch}');
      print('🔧 [MusicSearch] JS禁止回落: ${settings.jsOnlyNoFallback}');
      print('🔧 [MusicSearch] 脚本URL非空: ${settings.scriptUrl.isNotEmpty}');
      print('🔧 [MusicSearch] 使用统一API: ${settings.useUnifiedApi}');
      print('🔧 [MusicSearch] 使用YouTube代理: ${settings.useYouTubeProxy}');

      List<OnlineMusicResult> parsed = [];
      bool usedSpecialSource = false;

      // 🎯 线路0：YouTube代理搜索（需要翻墙）
      if (settings.useYouTubeProxy) {
        print('🌐 [MusicSearch] 线路0：使用YouTube代理进行搜索（需要翻墙）...');
        final youtubeService = ref.read(youtubeProxyServiceProvider);

        try {
          final results = await youtubeService
              .searchMusic(query: query, maxResults: 20)
              .timeout(
                const Duration(seconds: 20),
                onTimeout: () => <OnlineMusicResult>[],
              );

          print('🔍 [MusicSearch] YouTube代理返回 ${results.length} 个结果');
          parsed = results;
          usedSpecialSource = parsed.isNotEmpty;
        } catch (e) {
          print('❌ [MusicSearch] YouTube代理搜索异常: $e');
          print('💡 [MusicSearch] 提示：YouTube代理需要翻墙才能正常使用');
        }
      }
      // 🎯 线路1：使用统一API (music.txqq.pro) - 仅在YouTube代理未成功时执行
      if (!usedSpecialSource && settings.useUnifiedApi) {
        print('🌐 [MusicSearch] 线路1：使用统一API进行搜索和播放...');
        final unifiedService = ref.read(unifiedApiServiceProvider);

        try {
          final results = await unifiedService
              .searchMusic(
                query: query,
                platform:
                    settings.platform == 'auto' ? 'qq' : settings.platform,
                page: 1,
              )
              .timeout(
                const Duration(seconds: 15),
                onTimeout: () => <OnlineMusicResult>[],
              );

          print('🔍 [MusicSearch] 统一API返回 ${results.length} 个结果');
          parsed = results;
          usedSpecialSource = parsed.isNotEmpty;
        } catch (e) {
          print('❌ [MusicSearch] 统一API搜索异常: $e');
        }
      }
      // 🎯 线路2：使用JS源 - 仅在前面的特殊源都未成功时执行
      else if (!usedSpecialSource) {
        print('🌐 [MusicSearch] 线路2：使用JS源进行搜索和播放...');

        // 修正条件：如果开启了JS only模式，应该强制使用JS搜索
        bool shouldUseJs =
            settings.enabled &&
            settings.scriptUrl.isNotEmpty &&
            (settings.useJsForSearch || settings.jsOnlyNoFallback);

        print('🔧 [MusicSearch] 应该使用JS: $shouldUseJs');

        if (shouldUseJs) {
          print('🌐 [MusicSearch] 使用JS音源进行搜索...');
          final webSvc = await ref.read(webviewJsSourceServiceProvider.future);
          if (webSvc != null) {
            try {
              print('🔍 [MusicSearch] 开始WebView搜索，超时15秒...');
              final list = await webSvc
                  .search(query, platform: settings.platform)
                  .timeout(
                    const Duration(seconds: 15),
                    onTimeout: () {
                      print('⏰ [MusicSearch] WebView搜索超时');
                      return const [];
                    },
                  );
              print('🔍 searchOnline(webview): got ${list.length} items');
              parsed =
                  list
                      .map((e) {
                        final m = e;
                        print('🔍 [MusicSearch] 原始WebView项目: $m');
                        final platform =
                            (m['platform'] ?? m['source'] ?? m['type'] ?? '')
                                .toString();
                        final id =
                            (m['id'] ?? m['songmid'] ?? m['hash'] ?? '')
                                .toString();
                        final result = OnlineMusicResult(
                          title: (m['title'] ?? m['name'] ?? '').toString(),
                          author:
                              (m['artist'] ?? m['singer'] ?? m['author'] ?? '')
                                  .toString(),
                          url: (m['url'] ?? m['link'] ?? '').toString(),
                          picture: m['pic']?.toString(),
                          link: m['link']?.toString(),
                          platform: platform.isEmpty ? null : platform,
                          songId: id.isEmpty ? null : id,
                        );
                        print(
                          '🔍 [MusicSearch] 转换后: ${result.title} - ${result.author} - URL: ${result.url} - Platform: ${result.platform} - ID: ${result.songId}',
                        );
                        return result;
                      })
                      .where((e) => e.title.isNotEmpty)
                      .toList();
              usedSpecialSource = parsed.isNotEmpty;
            } catch (e) {
              print('❌ [MusicSearch] WebView搜索异常: $e');
            }
          }
          if (!usedSpecialSource) {
            final jsSvc = await ref.read(jsSourceServiceProvider.future);
            if (jsSvc != null) {
              try {
                print('🔍 [MusicSearch] 开始LocalJS搜索，超时15秒...');
                final list = await jsSvc
                    .search(query, platform: settings.platform)
                    .timeout(
                      const Duration(seconds: 15),
                      onTimeout: () {
                        print('⏰ [MusicSearch] LocalJS搜索超时');
                        return const [];
                      },
                    );
                print('🔍 searchOnline(local_js): got ${list.length} items');
                parsed =
                    list
                        .map((e) {
                          final m = e;
                          final platform =
                              (m['platform'] ?? m['source'] ?? m['type'] ?? '')
                                  .toString();
                          final id =
                              (m['id'] ?? m['songmid'] ?? m['hash'] ?? '')
                                  .toString();
                          return OnlineMusicResult(
                            title: (m['title'] ?? m['name'] ?? '').toString(),
                            author:
                                (m['artist'] ??
                                        m['singer'] ??
                                        m['author'] ??
                                        '')
                                    .toString(),
                            url: (m['url'] ?? m['link'] ?? '').toString(),
                            picture: m['pic']?.toString(),
                            link: m['link']?.toString(),
                            platform: platform.isEmpty ? null : platform,
                            songId: id.isEmpty ? null : id,
                          );
                        })
                        .where((e) => e.title.isNotEmpty)
                        .toList();
                usedSpecialSource = parsed.isNotEmpty;
              } catch (e) {
                print('❌ [MusicSearch] LocalJS搜索异常: $e');
              }
            }
          }
        }
      } // 结束 线路2：JS源

      // 如果特殊音源（统一API或JS源）未提供有效结果，回落到内置接口
      if (!usedSpecialSource) {
        final jsOnly = settings.jsOnlyNoFallback || settings.useUnifiedApi;
        if (jsOnly) {
          // 仅特殊音源模式：直接返回空列表，不触发回退
          state = state.copyWith(isLoading: false, onlineResults: const []);
          print('🔍 searchOnline: 特殊音源模式，不使用内置回退');
          return;
        }
        print('🔍 searchOnline(lx): request...');
        final data = await apiService
            .searchOnlineByTxqq(keyword: query)
            .timeout(const Duration(seconds: 12), onTimeout: () => const []);
        print('🔍 searchOnline(lx): got ${data.length} raw items');
        parsed =
            data
                .whereType<Map>()
                .map(
                  (e) =>
                      OnlineMusicResult.fromTxqqPro(e.cast<String, dynamic>()),
                )
                .toList();
      }

      state = state.copyWith(isLoading: false, onlineResults: parsed);
      print('🔍 searchOnline: done, parsed=${parsed.length}');
    } catch (e) {
      // ignore: avoid_print
      print('🔍 searchOnline: error=$e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        onlineResults: [],
      );
    }
  }

  void clearSearch() {
    state = state.copyWith(searchResults: [], searchQuery: '', error: null);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// 统一API服务Provider
final unifiedApiServiceProvider = Provider<UnifiedApiService>((ref) {
  final settings = ref.watch(sourceSettingsProvider);
  return UnifiedApiService(baseUrl: settings.unifiedApiBase);
});

// YouTube代理服务Provider
final youtubeProxyServiceProvider = Provider<YouTubeProxyService>((ref) {
  return YouTubeProxyService();
});

final musicSearchProvider =
    StateNotifierProvider<MusicSearchNotifier, MusicSearchState>((ref) {
      return MusicSearchNotifier(ref);
    });
