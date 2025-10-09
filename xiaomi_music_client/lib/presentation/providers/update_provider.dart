import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../data/services/leancloud_update_service.dart';

class UpdateState {
  final bool needsUpdate;
  final bool force;
  final String title;
  final String message;
  final String downloadUrl;
  final String targetVersion;

  const UpdateState({
    this.needsUpdate = false,
    this.force = false,
    this.title = '',
    this.message = '',
    this.downloadUrl = '',
    this.targetVersion = '',
  });

  UpdateState copyWith({
    bool? needsUpdate,
    bool? force,
    String? title,
    String? message,
    String? downloadUrl,
    String? targetVersion,
  }) {
    return UpdateState(
      needsUpdate: needsUpdate ?? this.needsUpdate,
      force: force ?? this.force,
      title: title ?? this.title,
      message: message ?? this.message,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      targetVersion: targetVersion ?? this.targetVersion,
    );
  }
}

class UpdateNotifier extends StateNotifier<UpdateState> {
  UpdateNotifier() : super(const UpdateState());

  int _compareVersions(String a, String b) {
    List<int> pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < 3; i++) {
      final da = i < pa.length ? pa[i] : 0;
      final db = i < pb.length ? pb[i] : 0;
      if (da != db) return da.compareTo(db);
    }
    return 0;
  }

  Future<void> check() async {
    final service = await LeanCloudUpdateService.create();
    if (service == null) return;
    try {
      final items = await service.fetchConfig();
      final active = {for (final it in items) it['key']: it};
      final enabledRaw = active['version_check_enabled']?['value'] ?? 'true';
      final enabled = enabledRaw.toString() == 'true';
      final target = (active['app_version']?['value'] ?? AppConstants.version).toString();
      final cmp = _compareVersions(AppConstants.version, target);
      final title = (active['update_title']?['value'] ?? '发现新版本').toString();
      final message = (active['update_message']?['value'] ?? '').toString();
      final url = (active['download_url']?['value'] ?? '').toString();
      final type = (active['update_type']?['value'] ?? 'optional').toString();

      if (enabled && cmp < 0) {
        state = state.copyWith(
          needsUpdate: true,
          force: type == 'force',
          title: title,
          message: message,
          downloadUrl: url,
          targetVersion: target,
        );
      }
    } catch (e) {
      // 可选：打印简要日志
    }
  }

  /// 忽略此次更新（仅用于非强制更新）
  void dismissUpdate() {
    if (!state.force) {
      state = const UpdateState();
    }
  }
}

final updateProvider = StateNotifierProvider<UpdateNotifier, UpdateState>((ref) => UpdateNotifier());
