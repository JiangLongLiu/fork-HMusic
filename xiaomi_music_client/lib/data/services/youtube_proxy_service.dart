import 'package:dio/dio.dart';
import 'dart:convert';
import '../models/online_music_result.dart';

/// YouTube代理API服务 (api.dlsrv.online)
/// 通过代理服务器搜索YouTube音乐视频
/// 注意：该服务需要翻墙或代理才能正常使用
class YouTubeProxyService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Host': 'api.dlsrv.online',
        'sec-ch-ua-platform': '"macOS"',
        'user-agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36',
        'sec-ch-ua':
            '"Not;A=Brand";v="99", "Google Chrome";v="139", "Chromium";v="139"',
        'content-type': 'application/json',
        'sec-ch-ua-mobile': '?0',
        'accept': '*/*',
        'origin': 'https://v4.mp3paw.link',
        'sec-fetch-site': 'cross-site',
        'sec-fetch-mode': 'cors',
        'sec-fetch-dest': 'empty',
        'referer': 'https://v4.mp3paw.link/',
        'accept-language': 'zh-CN,zh;q=0.9',
        'priority': 'u=1, i',
      },
    ),
  );

  static const String baseUrl = 'https://api.dlsrv.online';
  static const String searchEndpoint = '/api/search';

  // YouTube音频质量选项配置
  static const List<Map<String, dynamic>> audioQualities = [
    {
      'id': '320k',
      'name': '320kbps',
      'description': '高音质 (推荐)',
      'bitrate': 320,
      'color': 0xFF2196F3, // 蓝色
    },
    {
      'id': '256k',
      'name': '256kbps',
      'description': '较高音质',
      'bitrate': 256,
      'color': 0xFF4CAF50, // 绿色
    },
    {
      'id': '192k',
      'name': '192kbps',
      'description': '标准音质',
      'bitrate': 192,
      'color': 0xFF9C27B0, // 紫色
    },
    {
      'id': '128k',
      'name': '128kbps',
      'description': '普通音质',
      'bitrate': 128,
      'color': 0xFFFF9800, // 橙色
    },
    {
      'id': '64k',
      'name': '64kbps',
      'description': '节省流量',
      'bitrate': 64,
      'color': 0xFFF44336, // 红色
    },
  ];

  // YouTube音频下载服务配置
  static const List<Map<String, String>> downloadSources = [
    {
      'id': 'oceansaver',
      'name': 'OceanSaver',
      'description': '快速稳定，支持多种格式',
      'baseUrl': 'https://p.oceansaver.in',
      'endpoint': '/ajax/ad/l.php',
    },
    {
      'id': 'ytmp3',
      'name': 'YTMP3',
      'description': '高音质MP3下载',
      'baseUrl': 'https://ytmp3.cc',
      'endpoint': '/api/convert',
    },
    {
      'id': 'y2mate',
      'name': 'Y2mate',
      'description': '多格式支持，音质可选',
      'baseUrl': 'https://www.y2mate.com',
      'endpoint': '/mates/analyzeV2/ajax',
    },
  ];

  /// 搜索音乐视频
  Future<List<OnlineMusicResult>> searchMusic({
    required String query,
    int maxResults = 20,
  }) async {
    try {
      print('🔍 [YouTubeProxy] 搜索: $query (需要翻墙)');

      // 准备请求数据
      final requestData = {'query': query};

      print('🌐 [YouTubeProxy] 请求URL: $baseUrl$searchEndpoint');
      print('🌐 [YouTubeProxy] 请求数据: ${jsonEncode(requestData)}');

      // 发送POST请求
      final response = await _dio.post(
        '$baseUrl$searchEndpoint',
        data: jsonEncode(requestData),
        options: Options(
          responseType: ResponseType.json,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      print('🔍 [YouTubeProxy] 响应状态: ${response.statusCode}');

      if (response.statusCode == 200 && response.data != null) {
        final Map<String, dynamic> responseData = response.data;
        final List<dynamic> videos = responseData['data'] ?? [];

        print('🔍 [YouTubeProxy] 找到 ${videos.length} 个视频结果');

        // 转换为OnlineMusicResult格式
        final results =
            videos.take(maxResults).map<OnlineMusicResult>((video) {
              // 解析时长
              final durationStr = video['duration']?.toString() ?? '0:00';
              final duration = _parseDuration(durationStr);

              // 提取艺术家信息（从标题中尝试提取）
              final title = video['title']?.toString() ?? '未知标题';
              final artist = _extractArtistFromTitle(title);
              final cleanTitle = _cleanTitle(title);

              return OnlineMusicResult(
                title: cleanTitle,
                author: artist,
                url: video['url']?.toString() ?? '',
                picture: video['thumbnail']?.toString(),
                platform: 'youtube',
                songId: video['videoId']?.toString() ?? '',
                album: '',
                duration: duration,
                extra: {
                  'sourceApi': 'youtube_proxy',
                  'videoId': video['videoId']?.toString() ?? '',
                  'views': video['views']?.toString() ?? '',
                  'originalTitle': title,
                  'youtubeUrl': video['url']?.toString() ?? '',
                  'needsProxy': true, // 标记需要翻墙
                },
              );
            }).toList();

        print('🔍 [YouTubeProxy] 成功解析 ${results.length} 首歌曲');
        return results;
      }

      print('❌ [YouTubeProxy] 搜索失败: 状态码 ${response.statusCode}');
      return [];
    } catch (e) {
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          print('⏰ [YouTubeProxy] 连接超时 - 请检查网络连接或翻墙状态');
        } else if (e.response?.statusCode == 403 ||
            e.response?.statusCode == 429) {
          print('🚫 [YouTubeProxy] 访问被限制 - 可能需要更换代理或稍后重试');
        } else {
          print('❌ [YouTubeProxy] 网络错误: ${e.message}');
        }
      } else {
        print('❌ [YouTubeProxy] 搜索异常: $e');
      }
      return [];
    }
  }

  /// 获取YouTube视频的音频播放链接
  /// 使用多个下载源进行音频提取，支持音质智能降级
  Future<String?> getMusicUrl({
    required String videoId,
    String quality = '128k',
    String? preferredSource,
  }) async {
    try {
      print('🎵 [YouTubeProxy] 获取播放链接: videoId=$videoId, quality=$quality');
      print('🎵 [YouTubeProxy] 偏好下载源: $preferredSource');

      final youtubeUrl = 'https://www.youtube.com/watch?v=$videoId';

      // 根据偏好选择下载源，如果没有指定则使用默认顺序
      List<Map<String, String>> sourcesToTry = List.from(downloadSources);
      if (preferredSource != null) {
        final preferred = downloadSources.firstWhere(
          (source) => source['id'] == preferredSource,
          orElse: () => downloadSources.first,
        );
        sourcesToTry.remove(preferred);
        sourcesToTry.insert(0, preferred);
      }

      // 生成音质降级序列：从用户选择的音质开始，按照质量从高到低尝试
      final qualityFallbackList = _getQualityFallbackList(quality);
      print('🎵 [YouTubeProxy] 音质降级序列: ${qualityFallbackList.join(' -> ')}');

      // 尝试不同的下载源
      for (final source in sourcesToTry) {
        try {
          print('🔄 [YouTubeProxy] 尝试下载源: ${source['name']}');

          // 对每个下载源，尝试不同的音质（从高到低）
          for (final qualityToTry in qualityFallbackList) {
            try {
              if (qualityToTry != quality) {
                print('🔽 [YouTubeProxy] 降级尝试音质: $qualityToTry');
              }

              String? audioUrl;
              switch (source['id']) {
                case 'oceansaver':
                  audioUrl = await _getAudioUrlFromOceanSaver(
                    videoId,
                    youtubeUrl,
                    qualityToTry,
                  );
                  break;
                case 'ytmp3':
                  audioUrl = await _getAudioUrlFromYTMP3(
                    videoId,
                    youtubeUrl,
                    qualityToTry,
                  );
                  break;
                case 'y2mate':
                  audioUrl = await _getAudioUrlFromY2mate(
                    videoId,
                    youtubeUrl,
                    qualityToTry,
                  );
                  break;
                default:
                  print('⚠️ [YouTubeProxy] 未知下载源: ${source['id']}');
                  continue;
              }

              if (audioUrl != null &&
                  audioUrl.isNotEmpty &&
                  audioUrl.startsWith('http')) {
                print('✅ [YouTubeProxy] 成功获取音频链接: $audioUrl');
                print('✅ [YouTubeProxy] 使用下载源: ${source['name']}');
                if (qualityToTry != quality) {
                  print('🔽 [YouTubeProxy] 音质已降级: $quality -> $qualityToTry');
                } else {
                  print('🎵 [YouTubeProxy] 使用原始音质: $quality');
                }
                return audioUrl;
              }
            } catch (e) {
              print('❌ [YouTubeProxy] 音质 $qualityToTry 失败: $e');
              continue; // 尝试下一个音质
            }
          }
        } catch (e) {
          print('❌ [YouTubeProxy] 下载源 ${source['name']} 完全失败: $e');
          continue; // 尝试下一个下载源
        }
      }

      print('❌ [YouTubeProxy] 所有下载源和音质组合都失败了');
      return null;
    } catch (e) {
      print('❌ [YouTubeProxy] 获取播放链接异常: $e');
      return null;
    }
  }

  /// 使用OceanSaver获取音频链接
  Future<String?> _getAudioUrlFromOceanSaver(
    String videoId,
    String youtubeUrl,
    String quality,
  ) async {
    try {
      print('🌊 [OceanSaver] 开始获取音频链接...');

      // 第一步：获取初始重定向链接
      final dio = Dio(
        BaseOptions(
          followRedirects: false, // 手动处理重定向
          validateStatus: (status) => status != null && status < 500,
          headers: {
            'Host': 'p.oceansaver.in',
            'sec-ch-ua':
                '"Not;A=Brand";v="99", "Google Chrome";v="139", "Chromium";v="139"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"macOS"',
            'upgrade-insecure-requests': '1',
            'user-agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36',
            'accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
            'sec-fetch-site': 'cross-site',
            'sec-fetch-mode': 'navigate',
            'sec-fetch-user': '?1',
            'sec-fetch-dest': 'document',
            'referer': 'https://v4.mp3paw.link/',
            'accept-language': 'zh-CN,zh;q=0.9',
            'priority': 'u=0, i',
          },
        ),
      );

      // 构建请求参数 - 根据你的curl示例，这里可能需要特定的参数
      // 根据quality参数构建请求数据
      final qualityParam = _getOceanSaverQuality(quality);
      final response = await dio.post(
        'https://p.oceansaver.in/ajax/ad/l.php',
        data: {'url': youtubeUrl, 'quality': qualityParam, 'format': 'audio'},
        options: Options(contentType: 'application/x-www-form-urlencoded'),
      );

      print('🌊 [OceanSaver] 响应状态: ${response.statusCode}');

      if (response.statusCode == 302 || response.statusCode == 301) {
        // 处理重定向
        final redirectUrl = response.headers.value('location');
        if (redirectUrl != null) {
          print('🌊 [OceanSaver] 重定向到: $redirectUrl');
          return await _followRedirectForAudioUrl(redirectUrl);
        }
      } else if (response.statusCode == 200) {
        // 解析HTML响应中的重定向链接
        final html = response.data.toString();
        final redirectMatch = RegExp(r"url='([^']+)'").firstMatch(html);
        if (redirectMatch != null) {
          final redirectUrl = redirectMatch.group(1);
          print('🌊 [OceanSaver] HTML中的重定向链接: $redirectUrl');
          return await _followRedirectForAudioUrl(redirectUrl!);
        }
      }

      return null;
    } catch (e) {
      print('❌ [OceanSaver] 异常: $e');
      return null;
    }
  }

  /// 跟踪重定向并获取最终的音频URL
  Future<String?> _followRedirectForAudioUrl(String url) async {
    try {
      print('🔗 [Redirect] 跟踪重定向: $url');

      final dio = Dio(
        BaseOptions(
          followRedirects: true,
          maxRedirects: 5,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final response = await dio.get(url);

      if (response.statusCode == 200) {
        // 这里可能需要解析页面内容获取实际的下载链接
        final html = response.data.toString();

        // 寻找音频文件链接的模式
        final patterns = [
          RegExp(r'href="([^"]+\.mp3[^"]*)"'),
          RegExp(r'src="([^"]+\.mp3[^"]*)"'),
          RegExp(r'"url":"([^"]+\.mp3[^"]*)"'),
          RegExp(r'download_url["\s]*:["\s]*"([^"]+)"'),
        ];

        for (final pattern in patterns) {
          final match = pattern.firstMatch(html);
          if (match != null) {
            final audioUrl = match.group(1)!;
            if (audioUrl.startsWith('http')) {
              return audioUrl;
            }
          }
        }
      }

      return null;
    } catch (e) {
      print('❌ [Redirect] 跟踪重定向失败: $e');
      return null;
    }
  }

  /// 使用YTMP3获取音频链接
  Future<String?> _getAudioUrlFromYTMP3(
    String videoId,
    String youtubeUrl,
    String quality,
  ) async {
    try {
      print('🎵 [YTMP3] 开始获取音频链接...');

      final qualityParam = _getYTMP3Quality(quality);
      final response = await _dio.post(
        'https://ytmp3.cc/api/convert',
        data: {'url': youtubeUrl, 'format': 'mp3', 'quality': qualityParam},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['status'] == 'success' && data['download_url'] != null) {
          return data['download_url'].toString();
        }
      }

      return null;
    } catch (e) {
      print('❌ [YTMP3] 异常: $e');
      return null;
    }
  }

  /// 使用Y2mate获取音频链接
  Future<String?> _getAudioUrlFromY2mate(
    String videoId,
    String youtubeUrl,
    String quality,
  ) async {
    try {
      print('🎯 [Y2mate] 开始获取音频链接...');

      // Y2mate通常需要两步：首先分析视频，然后获取下载链接
      final qualityParam = _getY2mateQuality(quality);
      final analyzeResponse = await _dio.post(
        'https://www.y2mate.com/mates/analyzeV2/ajax',
        data: {
          'k_query': youtubeUrl,
          'k_page': 'home',
          'hl': 'en',
          'q_auto': '0',
          'quality': qualityParam, // 添加质量参数
        },
      );

      if (analyzeResponse.statusCode == 200) {
        final data = analyzeResponse.data;
        if (data['status'] == 'ok' && data['links'] != null) {
          // 寻找音频链接
          final links = data['links']['mp3'];
          if (links != null && links.isNotEmpty) {
            // 选择最佳质量的音频
            final audioKey = links.keys.first;
            final audioInfo = links[audioKey];

            if (audioInfo['k'] != null) {
              // 第二步：获取实际下载链接
              final convertResponse = await _dio.post(
                'https://www.y2mate.com/mates/convertV2/index',
                data: {'vid': data['vid'], 'k': audioInfo['k']},
              );

              if (convertResponse.statusCode == 200) {
                final convertData = convertResponse.data;
                if (convertData['status'] == 'ok' &&
                    convertData['dlink'] != null) {
                  return convertData['dlink'].toString();
                }
              }
            }
          }
        }
      }

      return null;
    } catch (e) {
      print('❌ [Y2mate] 异常: $e');
      return null;
    }
  }

  /// 生成音质降级列表：从用户选择的音质开始，按优先级排列所有音质
  ///
  /// 降级策略：
  /// 1. 优先尝试用户选择的音质
  /// 2. 如果失败，尝试更高的音质（更接近用户选择的优先）
  /// 3. 最后尝试更低的音质（按从高到低顺序）
  ///
  /// 示例：
  /// - 选择192k -> [192k, 256k, 320k, 128k, 64k]
  /// - 选择320k -> [320k, 256k, 192k, 128k, 64k]
  /// - 选择64k -> [64k, 128k, 192k, 256k, 320k]
  List<String> _getQualityFallbackList(String preferredQuality) {
    // 定义音质优先级（从高到低）
    const qualityPriority = ['320k', '256k', '192k', '128k', '64k'];

    // 找到用户选择音质的索引
    final preferredIndex = qualityPriority.indexOf(preferredQuality);

    if (preferredIndex == -1) {
      // 用户选择的音质不在列表中，返回默认降级序列
      print('⚠️ [YouTubeProxy] 未知音质 $preferredQuality，使用默认序列');
      return List.from(qualityPriority);
    }

    List<String> fallbackList = [];

    // 1. 首先添加用户选择的音质
    fallbackList.add(preferredQuality);

    // 2. 添加比用户选择音质更高的音质（按从接近到远离的顺序）
    // 例如用户选择192k，会添加 256k, 320k
    for (int i = preferredIndex - 1; i >= 0; i--) {
      fallbackList.add(qualityPriority[i]);
    }

    // 3. 添加比用户选择音质更低的音质（按从高到低的顺序）
    // 例如用户选择192k，会添加 128k, 64k
    for (int i = preferredIndex + 1; i < qualityPriority.length; i++) {
      fallbackList.add(qualityPriority[i]);
    }

    print(
      '🔽 [YouTubeProxy] 为音质 $preferredQuality 生成降级序列: ${fallbackList.join(' -> ')}',
    );
    return fallbackList;
  }

  /// 获取OceanSaver下载源支持的质量参数
  String _getOceanSaverQuality(String quality) {
    // OceanSaver 可能支持的质量参数格式
    switch (quality) {
      case '320k':
        return 'mp3-320';
      case '256k':
        return 'mp3-256';
      case '192k':
        return 'mp3-192';
      case '128k':
        return 'mp3-128';
      case '64k':
        return 'mp3-64';
      default:
        return 'mp3'; // 默认格式
    }
  }

  /// 获取YTMP3下载源支持的质量参数
  String _getYTMP3Quality(String quality) {
    // YTMP3 质量参数格式 (通常为数字)
    switch (quality) {
      case '320k':
        return '320';
      case '256k':
        return '256';
      case '192k':
        return '192';
      case '128k':
        return '128';
      case '64k':
        return '64';
      default:
        return '128'; // 默认128kbps
    }
  }

  /// 获取Y2mate下载源支持的质量参数
  String _getY2mateQuality(String quality) {
    // Y2mate 可能需要特定的格式
    switch (quality) {
      case '320k':
        return 'mp3-320kbps';
      case '256k':
        return 'mp3-256kbps';
      case '192k':
        return 'mp3-192kbps';
      case '128k':
        return 'mp3-128kbps';
      case '64k':
        return 'mp3-64kbps';
      default:
        return 'mp3-128kbps'; // 默认
    }
  }

  /// 解析时长字符串 (如 "4:24" -> 264秒)
  int _parseDuration(String duration) {
    try {
      final parts = duration.split(':');
      if (parts.length == 2) {
        final minutes = int.parse(parts[0]);
        final seconds = int.parse(parts[1]);
        return minutes * 60 + seconds;
      } else if (parts.length == 3) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final seconds = int.parse(parts[2]);
        return hours * 3600 + minutes * 60 + seconds;
      }
    } catch (e) {
      print('⚠️ [YouTubeProxy] 时长解析失败: $duration');
    }
    return 0;
  }

  /// 从标题中提取艺术家信息
  String _extractArtistFromTitle(String title) {
    // 常见的分隔符模式
    final patterns = [
      RegExp(r'(.+?)\s*[-–—]\s*(.+?)(?:\s*\[|\s*\(|$)'), // Artist - Title
      RegExp(r'(.+?)\s*[【\[]\s*(.+?)\s*[】\]]'), // Artist【Title】
      RegExp(r'(.+?)\s*『(.+?)』'), // Artist『Title』
      RegExp(r'(.+?)\s*《(.+?)》'), // Artist《Title》
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(title);
      if (match != null && match.groupCount >= 1) {
        return match.group(1)?.trim() ?? '未知艺术家';
      }
    }

    // 如果没有匹配到模式，查找常见的艺术家标识
    if (title.contains('Jay Chou') || title.contains('周杰伦')) return '周杰伦';
    if (title.contains('Taylor Swift')) return 'Taylor Swift';
    // 可以添加更多常见艺术家识别规则

    return '未知艺术家';
  }

  /// 清理标题，移除多余信息
  String _cleanTitle(String title) {
    // 移除常见的后缀
    final suffixPatterns = [
      RegExp(r'\s*-?\s*Official\s+(Music\s+)?Video', caseSensitive: false),
      RegExp(r'\s*\(Official\s+(Music\s+)?Video\)', caseSensitive: false),
      RegExp(r'\s*\[Official\s+(Music\s+)?Video\]', caseSensitive: false),
      RegExp(r'\s*MV\s*$', caseSensitive: false),
      RegExp(r'\s*4K\s*$', caseSensitive: false),
      RegExp(r'\s*HD\s*$', caseSensitive: false),
      RegExp(r'\s*\d+p\s*$', caseSensitive: false),
    ];

    String cleanTitle = title;
    for (final pattern in suffixPatterns) {
      cleanTitle = cleanTitle.replaceFirst(pattern, '');
    }

    // 提取【】或[]中的歌曲名
    final titleMatch = RegExp(r'[【\[]([^】\]]+)[】\]]').firstMatch(cleanTitle);
    if (titleMatch != null) {
      return titleMatch.group(1)?.trim() ?? cleanTitle.trim();
    }

    // 提取引号中的歌曲名
    final quoteMatch = RegExp(r'["""]([^"""]+)["""]').firstMatch(cleanTitle);
    if (quoteMatch != null) {
      return quoteMatch.group(1)?.trim() ?? cleanTitle.trim();
    }

    return cleanTitle.trim();
  }

  /// 检查网络连接和代理状态
  Future<bool> testConnection() async {
    try {
      print('🔧 [YouTubeProxy] 测试连接...');
      final response = await _dio
          .post(
            '$baseUrl$searchEndpoint',
            data: jsonEncode({'query': 'test'}),
            options: Options(
              responseType: ResponseType.json,
              validateStatus: (status) => true, // 接受所有状态码
            ),
          )
          .timeout(const Duration(seconds: 5));

      final isOk = response.statusCode == 200;
      print(
        isOk
            ? '✅ [YouTubeProxy] 连接正常'
            : '❌ [YouTubeProxy] 连接异常: ${response.statusCode}',
      );
      return isOk;
    } catch (e) {
      print('❌ [YouTubeProxy] 连接测试失败: $e');
      return false;
    }
  }

  /// 获取支持信息
  Map<String, dynamic> getServiceInfo() {
    return {
      'name': 'YouTube代理搜索',
      'description': '通过代理服务器搜索YouTube音乐视频',
      'baseUrl': baseUrl,
      'needsProxy': true,
      'supports': ['搜索', '视频信息'],
      'limitations': ['需要翻墙', '音频链接需要额外转换'],
      'platforms': ['youtube'],
    };
  }

  /// 释放资源
  void dispose() {
    _dio.close();
  }
}
