import '../../core/network/dio_client.dart';
import 'package:dio/dio.dart';

class UploadFile {
  final String fieldName;
  final String filePath;

  const UploadFile({required this.fieldName, required this.filePath});
}

class MusicApiService {
  final DioClient _client;

  MusicApiService(this._client);

  Future<Map<String, dynamic>> getVersion() async {
    final response = await _client.get('/getversion');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMusicList() async {
    final response = await _client.get('/musiclist');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCurrentPlaying({String? did}) async {
    final response = await _client.get(
      '/playingmusic',
      queryParameters: did != null ? {'did': did} : null,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getVolume({String? did}) async {
    final response = await _client.get(
      '/getvolume',
      queryParameters: did != null ? {'did': did} : null,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> setVolume({required String did, required int volume}) async {
    await _client.post('/setvolume', data: {'did': did, 'volume': volume});
  }

  // 可选：若服务端支持拖动进度
  Future<void> seek({required String did, required int seconds}) async {
    await _client.post('/seek', data: {'did': did, 'seconds': seconds});
  }

  Future<void> playMusic({
    required String did,
    String? musicName,
    String? searchKey,
  }) async {
    await _client.post(
      '/playmusic',
      data: {
        'did': did,
        'musicname': musicName ?? '',
        'searchkey': searchKey ?? '',
      },
    );
  }

  Future<void> pauseMusic({required String did}) async {
    await _client.post('/cmd', data: {'did': did, 'cmd': '暂停'});
  }

  Future<void> resumeMusic({required String did}) async {
    await _client.post('/cmd', data: {'did': did, 'cmd': '播放'});
  }

  Future<void> shutdown({required String did}) async {
    await _client.post('/cmd', data: {'did': did, 'cmd': '关机'});
  }

  Future<void> executeCommand({
    required String did,
    required String command,
  }) async {
    await _client.post('/cmd', data: {'did': did, 'cmd': command});
  }

  Future<Map<String, dynamic>> getCommandStatus() async {
    final response = await _client.get('/cmdstatus');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSettings({
    bool needDeviceList = false,
  }) async {
    final response = await _client.get(
      '/getsetting',
      queryParameters: {'need_device_list': needDeviceList},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> searchMusic(String name) async {
    final response = await _client.get(
      '/searchmusic',
      queryParameters: {'name': name},
    );
    return response.data as List<dynamic>;
  }

  Future<void> playUrl({required String did, required String url}) async {
    await _client.get('/playurl', queryParameters: {'did': did, 'url': url});
  }

  Future<void> playTts({required String did, required String text}) async {
    await _client.get('/playtts', queryParameters: {'did': did, 'text': text});
  }

  // 预留：本地音乐上传（待确认服务端路径/参数）
  Future<Map<String, dynamic>> uploadMusic({
    required List<({String fieldName, String filePath})> files,
    Map<String, dynamic>? extraFields,
    String endpoint = '/uploadmusic',
  }) async {
    final formData = FormData();
    for (final f in files) {
      formData.files.add(
        MapEntry(f.fieldName, await MultipartFile.fromFile(f.filePath)),
      );
    }
    if (extraFields != null) {
      formData.fields.addAll(
        extraFields.entries.map((e) => MapEntry(e.key, e.value.toString())),
      );
    }
    final resp = await _client.post(endpoint, data: formData);
    return (resp.data as Map).cast<String, dynamic>();
  }

  // 预留：网络音乐下载（待确认服务端路径/参数）
  Future<Map<String, dynamic>> downloadMusicByUrl({
    required String url,
    Map<String, dynamic>? extraFields,
    String endpoint = '/download',
  }) async {
    final body = {'url': url, ...?extraFields};
    final resp = await _client.post(endpoint, data: body);
    return (resp.data as Map).cast<String, dynamic>();
  }

  // 播放列表相关方法
  Future<dynamic> getPlaylistNames() async {
    // 兼容不同服务端实现：可能返回 List 或 Map
    final response = await _client.get('/playlistnames');
    return response.data;
  }

  Future<Map<String, dynamic>> getPlaylistMusics(String playlistName) async {
    final response = await _client.get(
      '/playlistmusics',
      queryParameters: {'name': playlistName},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> playMusicList({
    required String deviceId,
    required String playlistName,
    String? musicName,
  }) async {
    await _client.post(
      '/playmusiclist',
      data: {
        'did': deviceId,
        'listname': playlistName,
        'musicname': musicName ?? '',
      },
    );
  }

  Future<void> createPlaylist(String name) async {
    await _client.post('/playlistadd', data: {'name': name});
  }

  Future<void> deletePlaylist(String name) async {
    await _client.post('/playlistdel', data: {'name': name});
  }

  Future<void> renamePlaylist({
    required String oldName,
    required String newName,
  }) async {
    await _client.post(
      '/playlistupdatename',
      data: {'oldname': oldName, 'newname': newName},
    );
  }

  Future<void> addMusicToPlaylist({
    required String playlistName,
    required List<String> musicList,
  }) async {
    await _client.post(
      '/playlistaddmusic',
      data: {'name': playlistName, 'music_list': musicList},
    );
  }

  Future<void> removeMusicFromPlaylist({
    required String playlistName,
    required List<String> musicList,
  }) async {
    await _client.post(
      '/playlistdelmusic',
      data: {'name': playlistName, 'music_list': musicList},
    );
  }

  // 音乐库相关方法
  Future<void> deleteMusic(String musicName) async {
    await _client.post('/delmusic', data: {'name': musicName});
  }

  Future<Map<String, dynamic>> getMusicInfo(
    String musicName, {
    bool includeTag = false,
  }) async {
    final response = await _client.get(
      '/musicinfo',
      queryParameters: {'name': musicName, 'musictag': includeTag},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getMusicInfos(
    List<String> musicNames, {
    bool includeTag = false,
  }) async {
    final response = await _client.get(
      '/musicinfos',
      queryParameters: {'name': musicNames, 'musictag': includeTag},
    );
    return response.data as List<dynamic>;
  }

  Future<void> setMusicTag(Map<String, dynamic> musicInfo) async {
    await _client.post('/setmusictag', data: musicInfo);
  }

  // 网络下载：整表
  Future<Map<String, dynamic>> downloadPlaylist({
    required String playlistName,
    String? url,
  }) async {
    final payload = {'dirname': playlistName, if (url != null) 'url': url};
    final resp = await _client.post('/downloadplaylist', data: payload);
    return (resp.data as Map).cast<String, dynamic>();
  }

  // 网络下载：单曲
  Future<Map<String, dynamic>> downloadOneMusic({
    required String musicName,
    String? url,
  }) async {
    final payload = {'name': musicName, if (url != null) 'url': url};
    final resp = await _client.post('/downloadonemusic', data: payload);
    return (resp.data as Map).cast<String, dynamic>();
  }

  // 通用文件上传方法
  Future<Map<String, dynamic>> uploadFiles({
    required String endpoint,
    required List<UploadFile> files,
    Map<String, dynamic>? extraFields,
  }) async {
    final formData = FormData();

    // 添加文件
    for (final f in files) {
      formData.files.add(
        MapEntry(f.fieldName, await MultipartFile.fromFile(f.filePath)),
      );
    }

    // 添加额外字段
    if (extraFields != null) {
      formData.fields.addAll(
        extraFields.entries.map((e) => MapEntry(e.key, e.value.toString())),
      );
    }

    final resp = await _client.post(endpoint, data: formData);
    return (resp.data as Map).cast<String, dynamic>();
  }
}
