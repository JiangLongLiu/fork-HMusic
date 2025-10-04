import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/device.dart';
import 'auth_provider.dart';
import 'dio_provider.dart';

// 用于区分"未传入参数"和"传入 null"
const _undefined = Object();

class DeviceState {
  final List<Device> devices;
  final String? selectedDeviceId;
  final bool isLoading;
  final String? error;

  const DeviceState({
    this.devices = const [],
    this.selectedDeviceId,
    this.isLoading = false,
    this.error,
  });

  DeviceState copyWith({
    List<Device>? devices,
    Object? selectedDeviceId = _undefined,
    bool? isLoading,
    String? error,
  }) {
    return DeviceState(
      devices: devices ?? this.devices,
      selectedDeviceId:
          selectedDeviceId == _undefined
              ? this.selectedDeviceId
              : selectedDeviceId as String?,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class DeviceNotifier extends StateNotifier<DeviceState> {
  final Ref ref;

  DeviceNotifier(this.ref) : super(const DeviceState()) {
    // 监听认证状态变化
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next is AuthAuthenticated && prev is! AuthAuthenticated) {
        // 用户登录后自动加载设备列表
        debugPrint('DeviceProvider: 用户已认证，自动加载设备列表');
        Future.delayed(const Duration(milliseconds: 1000), () {
          loadDevices();
        });
      }
      if (next is AuthInitial) {
        // 登出时清空设备状态
        state = const DeviceState();
      }
    });
  }

  Future<void> loadDevices() async {
    final apiService = ref.read(apiServiceProvider);
    if (apiService == null) {
      state = state.copyWith(isLoading: false, error: 'API 服务未初始化');
      return;
    }

    try {
      state = state.copyWith(isLoading: true);

      final response = await apiService.getSettings(needDeviceList: true);
      final deviceList = response['device_list'] as List<dynamic>? ?? [];

      final devices =
          deviceList
              .map((json) {
                final deviceData = json as Map<String, dynamic>;
                final deviceID = deviceData['deviceID']?.toString() ?? '';
                final miotDID = deviceData['miotDID']?.toString() ?? '';
                final deviceName =
                    deviceData['name']?.toString() ??
                    deviceData['alias']?.toString() ??
                    '未知设备';

                return Device(
                  id: miotDID.isNotEmpty ? miotDID : deviceID,
                  name: deviceName,
                  type: deviceData['hardware']?.toString(),
                  isOnline:
                      deviceData['presence']?.toString() == 'online' ||
                      deviceData['current'] == true,
                  ip: deviceData['address']?.toString(),
                );
              })
              .where((device) => device.id.isNotEmpty)
              .toList();

      state = state.copyWith(devices: devices, isLoading: false, error: null);

      // 🎯 当设备列表为空时，清除选中的设备ID
      if (devices.isEmpty) {
        state = state.copyWith(selectedDeviceId: null);
      } else if (devices.isNotEmpty && state.selectedDeviceId == null) {
        // 有设备但没有选中任何设备时，自动选中第一个在线设备
        final onlineDevice = devices.firstWhere(
          (d) => d.isOnline == true,
          orElse: () => devices.first,
        );
        state = state.copyWith(selectedDeviceId: onlineDevice.id);
      } else if (devices.isNotEmpty && state.selectedDeviceId != null) {
        // 有设备且已选中设备时，检查该设备是否还在列表中
        final exists = devices.any((d) => d.id == state.selectedDeviceId);
        if (!exists) {
          // 之前选中的设备不在列表中，重新选择一个在线设备
          final onlineDevice = devices.firstWhere(
            (d) => d.isOnline == true,
            orElse: () => devices.first,
          );
          state = state.copyWith(selectedDeviceId: onlineDevice.id);
        }
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void selectDevice(String deviceId) {
    state = state.copyWith(selectedDeviceId: deviceId);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final deviceProvider = StateNotifierProvider<DeviceNotifier, DeviceState>((
  ref,
) {
  return DeviceNotifier(ref);
});
