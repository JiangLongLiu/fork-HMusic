import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'unified_api_service.dart';
import 'music_api_service.dart';

/// 专辑封面服务
/// 负责从在线音乐平台刮削封面并上传到NAS服务器
class AlbumCoverService {
  final UnifiedApiService _unifiedApi;
  final MusicApiService _musicApi;
  final Dio _dio = Dio();

  AlbumCoverService({
    required UnifiedApiService unifiedApi,
    required MusicApiService musicApi,
  })  : _unifiedApi = unifiedApi,
        _musicApi = musicApi;

  /// 获取歌曲封面（如果没有则自动刮削并上传）
  ///
  /// 返回值：
  /// - 有封面：返回封面URL（已替换为登录域名）
  /// - 无封面且刮削成功：返回新的封面URL
  /// - 无封面且刮削失败：返回null
  Future<String?> getOrFetchAlbumCover({
    required String musicName,
    required String loginBaseUrl,
    bool autoScrape = true,
  }) async {
    try {
      debugPrint('🖼️ [AlbumCover] 获取封面: $musicName');

      // 1. 先从服务器获取音乐信息
      final musicInfo = await _musicApi.getMusicInfo(musicName, includeTag: true);
      String? pictureUrl = musicInfo['tags']?['picture']?.toString();

      // 2. 如果有封面，替换内网地址后返回
      if (pictureUrl != null && pictureUrl.isNotEmpty) {
        debugPrint('✅ [AlbumCover] 服务器已有封面: $pictureUrl');
        return _replaceWithLoginDomain(pictureUrl, loginBaseUrl);
      }

      // 3. 如果没有封面且允许自动刮削
      if (!autoScrape) {
        debugPrint('⚠️ [AlbumCover] 无封面，跳过刮削');
        return null;
      }

      debugPrint('🔍 [AlbumCover] 无封面，开始在线刮削...');

      // 4. 在线搜索封面
      pictureUrl = await _scrapeAlbumCover(musicName);
      if (pictureUrl == null || pictureUrl.isEmpty) {
        debugPrint('❌ [AlbumCover] 刮削失败，未找到封面');
        return null;
      }

      debugPrint('✅ [AlbumCover] 刮削成功: $pictureUrl');

      // 5. 下载封面并转换为base64
      final base64Picture = await _downloadAndConvertToBase64(pictureUrl);
      if (base64Picture == null) {
        debugPrint('❌ [AlbumCover] 下载封面失败');
        return null;
      }

      debugPrint('✅ [AlbumCover] 封面下载完成，准备上传...');

      // 6. 上传到服务器
      await _uploadAlbumCover(musicName, base64Picture);

      debugPrint('✅ [AlbumCover] 封面上传成功');

      // 7. 重新获取封面URL
      final updatedMusicInfo = await _musicApi.getMusicInfo(musicName, includeTag: true);
      pictureUrl = updatedMusicInfo['tags']?['picture']?.toString();

      if (pictureUrl != null && pictureUrl.isNotEmpty) {
        return _replaceWithLoginDomain(pictureUrl, loginBaseUrl);
      }

      return null;
    } catch (e) {
      debugPrint('❌ [AlbumCover] 获取封面失败: $e');
      return null;
    }
  }

  /// 在线搜索并获取封面URL
  Future<String?> _scrapeAlbumCover(String musicName) async {
    try {
      // 解析歌曲名（格式：歌曲名 - 歌手名）
      final parts = musicName.split(' - ');
      final songName = parts.isNotEmpty ? parts[0].trim() : musicName;

      debugPrint('🔍 [AlbumCover] 搜索: $songName');

      // 使用QQ音乐搜索（可根据需要切换平台）
      final results = await _unifiedApi.searchMusic(
        query: songName,
        platform: 'qq',
        page: 1,
      );

      if (results.isEmpty) {
        debugPrint('⚠️ [AlbumCover] 搜索无结果');
        return null;
      }

      // 取第一个结果
      final firstResult = results.first;

      // 检查是否有封面URL（来自extra字段）
      final rawData = firstResult.extra?['rawData'];
      if (rawData is Map) {
        // 尝试从不同字段获取封面
        final pic = rawData['pic'] ?? rawData['cover'] ?? rawData['album_pic'] ?? rawData['albumPic'];
        if (pic != null && pic.toString().isNotEmpty) {
          String picUrl = pic.toString();

          // 处理相对路径
          if (!picUrl.startsWith('http')) {
            if (picUrl.startsWith('//')) {
              picUrl = 'https:$picUrl';
            } else if (picUrl.startsWith('/')) {
              picUrl = 'https://y.qq.com$picUrl';
            }
          }

          debugPrint('✅ [AlbumCover] 找到封面: $picUrl');
          return picUrl;
        }
      }

      debugPrint('⚠️ [AlbumCover] 搜索结果无封面字段');
      return null;
    } catch (e) {
      debugPrint('❌ [AlbumCover] 搜索失败: $e');
      return null;
    }
  }

  /// 下载封面并转换为base64
  Future<String?> _downloadAndConvertToBase64(String imageUrl) async {
    try {
      debugPrint('📥 [AlbumCover] 下载封面: $imageUrl');

      final response = await _dio.get<Uint8List>(
        imageUrl,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Referer': 'https://y.qq.com/',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final base64String = base64Encode(response.data!);
        debugPrint('✅ [AlbumCover] 转换完成，大小: ${response.data!.length} bytes');
        return base64String;
      }

      debugPrint('❌ [AlbumCover] 下载失败: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('❌ [AlbumCover] 下载异常: $e');
      return null;
    }
  }

  /// 上传封面到NAS服务器
  Future<void> _uploadAlbumCover(String musicName, String base64Picture) async {
    debugPrint('📤 [AlbumCover] 上传封面到服务器: $musicName');

    await _musicApi.setMusicTag({
      'musicname': musicName,
      'picture': base64Picture,
    });
  }

  /// 将内网地址替换为登录域名
  String _replaceWithLoginDomain(String nasUrl, String loginBaseUrl) {
    try {
      final loginUri = Uri.parse(loginBaseUrl);
      final nasUri = Uri.parse(nasUrl);

      final replacedUri = nasUri.replace(
        scheme: loginUri.scheme,
        host: loginUri.host,
        port: loginUri.port,
      );

      return replacedUri.toString();
    } catch (e) {
      debugPrint('❌ [AlbumCover] URL替换失败: $e');
      return nasUrl;
    }
  }

  /// 释放资源
  void dispose() {
    _dio.close();
  }
}
