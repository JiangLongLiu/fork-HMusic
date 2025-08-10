import 'package:json_annotation/json_annotation.dart';

part 'device.g.dart';

@JsonSerializable()
class Device {
  final String id;
  final String name;
  final String? type;
  final bool? isOnline;
  final String? ip;
  
  const Device({
    required this.id,
    required this.name,
    this.type,
    this.isOnline,
    this.ip,
  });
  
  factory Device.fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceToJson(this);
}