import 'package:dio/dio.dart';
import 'dart:convert';
import '../models/online_music_result.dart';

/// 统一API服务 (music.txqq.pro)
/// 提供多平台统一的搜索和播放功能
class UnifiedApiService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/plain, */*',
        'Referer': 'https://music.txqq.pro/',
      },
    ),
  );

  final String baseUrl;

  UnifiedApiService({this.baseUrl = 'https://music.txqq.pro'});

  /// 搜索音乐
  /// platform: wangyi, qq, kugou, kuwo, qianqian, yiting, migu 等
  Future<List<OnlineMusicResult>> searchMusic({
    required String query,
    String platform = 'qq',
    int page = 1,
  }) async {
    try {
      print('🔍 [UnifiedAPI] 搜索: $query, 平台: $platform, 页码: $page');

      // 使用与 music_api_service.dart 相同的接口格式
      final String encodedKw = Uri.encodeQueryComponent(query);

      // 设置正确的请求头
      _dio.options.headers.addAll({
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'Origin': 'https://music.txqq.pro',
        'Referer': 'https://music.txqq.pro/?name=$encodedKw&type=$platform',
        'X-Requested-With': 'XMLHttpRequest',
        'Accept': 'application/json, text/javascript, */*; q=0.01',
      });

      // music.txqq.pro 的实际搜索接口（POST到根路径）
      final response = await _dio.post(
        baseUrl,
        data: 'input=$encodedKw&filter=name&type=$platform&page=$page',
        options: Options(responseType: ResponseType.plain),
      );

      print('🔍 [UnifiedAPI] 搜索响应状态: ${response.statusCode}');

      if (response.statusCode == 200 && response.data != null) {
        // 手动解析JSON响应
        var body = response.data;
        if (body is! String) {
          body = body.toString();
        }

        dynamic jsonBody;
        try {
          jsonBody = jsonDecode(body);
        } catch (_) {
          print('❌ [UnifiedAPI] JSON解析失败');
          return [];
        }

        final List<dynamic> songs = jsonBody['data'] ?? [];
        print('🔍 [UnifiedAPI] 原始数据包含 ${songs.length} 个结果');

        final results =
            songs.map<OnlineMusicResult>((item) {
              return OnlineMusicResult(
                title: item['title']?.toString() ?? '未知标题',
                author: item['author']?.toString() ?? '未知艺术家',
                album: '',
                duration: 0,
                url: item['url']?.toString() ?? '', // 这里可能直接包含播放链接
                platform: platform,
                songId:
                    item['songid']?.toString() ?? item['id']?.toString() ?? '',
                // 保存原始数据用于播放链接获取
                extra: {'rawData': item, 'sourceApi': 'unified'},
              );
            }).toList();

        print('🔍 [UnifiedAPI] 解析到 ${results.length} 首歌曲');
        return results;
      }

      print('❌ [UnifiedAPI] 搜索失败: 状态码 ${response.statusCode}');
      return [];
    } catch (e) {
      print('❌ [UnifiedAPI] 搜索异常: $e');
      return [];
    }
  }

  /// 获取播放链接
  /// 注意：使用同样的平台获取播放链接，确保版权一致性
  Future<String?> getMusicUrl({
    required String songId,
    required String platform,
    String quality = '320k',
  }) async {
    try {
      print(
        '🎵 [UnifiedAPI] 获取播放链接: songId=$songId, platform=$platform, quality=$quality',
      );

      // music.txqq.pro 通过ID获取播放链接，使用与搜索相同的接口格式
      final String encodedId = Uri.encodeQueryComponent(songId);

      // 设置正确的请求头
      _dio.options.headers.addAll({
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'Origin': 'https://music.txqq.pro',
        'Referer': 'https://music.txqq.pro/?name=$encodedId&type=$platform',
        'X-Requested-With': 'XMLHttpRequest',
        'Accept': 'application/json, text/javascript, */*; q=0.01',
      });

      // 使用songId作为input参数来获取播放链接
      final response = await _dio.post(
        baseUrl,
        data: 'input=$encodedId&filter=id&type=$platform&page=1',
        options: Options(responseType: ResponseType.plain),
      );

      print('🎵 [UnifiedAPI] 播放链接响应状态: ${response.statusCode}');

      if (response.statusCode == 200 && response.data != null) {
        // 手动解析JSON响应
        var body = response.data;
        if (body is! String) {
          body = body.toString();
        }

        dynamic jsonBody;
        try {
          jsonBody = jsonDecode(body);
        } catch (_) {
          print('❌ [UnifiedAPI] JSON解析失败');
          return null;
        }

        final List<dynamic> songs = jsonBody['data'] ?? [];
        if (songs.isNotEmpty) {
          final String? url = songs[0]['url']?.toString();

          if (url != null && url.isNotEmpty) {
            print('✅ [UnifiedAPI] 成功获取播放链接: $url');
            // 检查是否是有效链接
            if (url.startsWith('http')) {
              return url;
            } else {
              print('⚠️ [UnifiedAPI] 无效的播放链接格式: $url');
              return null;
            }
          } else {
            print('❌ [UnifiedAPI] 响应中没有播放链接');
            return null;
          }
        } else {
          print('❌ [UnifiedAPI] 没有找到对应的歌曲');
          return null;
        }
      }

      print('❌ [UnifiedAPI] 获取播放链接失败: 状态码 ${response.statusCode}');
      return null;
    } catch (e) {
      print('❌ [UnifiedAPI] 获取播放链接异常: $e');
      return null;
    }
  }

  /// 获取支持的平台列表
  List<Map<String, String>> getSupportedPlatforms() {
    return [
      {'id': 'wangyi', 'name': '网易云音乐'},
      {'id': 'qq', 'name': 'QQ音乐'},
      {'id': 'kugou', 'name': '酷狗音乐'},
      {'id': 'kuwo', 'name': '酷我音乐'},
      {'id': 'qianqian', 'name': '千千音乐'},
      {'id': 'yiting', 'name': '一听音乐'},
      {'id': 'migu', 'name': '咪咕音乐'},
    ];
  }

  /// 释放资源
  void dispose() {
    _dio.close();
  }
}
