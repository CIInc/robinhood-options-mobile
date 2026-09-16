import 'package:cloud_firestore/cloud_firestore.dart';

class Device {
  String id;
  String? model;
  String? apnsToken;
  String? fcmToken;
  String? appVersion;
  Map<String, dynamic>? deviceInfo;
  DateTime dateCreated;
  DateTime? dateUpdated;

  Device(
      {required this.id,
      this.model,
      this.apnsToken,
      this.fcmToken,
      this.appVersion,
      this.deviceInfo,
      required this.dateCreated,
      this.dateUpdated});

  Device.fromJson(Map<String, Object?> json)
      : this(
            id: json['id'] as String,
            model: json['model'] as String?,
            apnsToken: json['apnsToken'] as String?,
            fcmToken: json['fcmToken'] as String?,
            appVersion: json['appVersion'] as String?,
            deviceInfo: json['deviceInfo'] as Map<String, dynamic>?,
            dateCreated: (json['dateCreated'] as Timestamp).toDate(),
            dateUpdated: json['dateUpdated'] != null
                ? (json['dateUpdated'] as Timestamp).toDate()
                : null);

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'model': model,
      'apnsToken': apnsToken,
      'fcmToken': fcmToken,
      'appVersion': appVersion,
      'deviceInfo': deviceInfo,
      'dateCreated': dateCreated,
      'dateUpdated': dateUpdated
    };
  }

  static List<Device> fromJsonArray(dynamic json) {
    List<Device> list = [];
    for (int i = 0; i < json.length; i++) {
      list.add(Device.fromJson(json[i]));
    }
    return list;
  }
}
