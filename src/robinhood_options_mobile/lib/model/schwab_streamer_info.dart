import 'package:flutter/foundation.dart';

@immutable
class SchwabStreamerInfo {
  final String streamerSocketUrl;
  final String schwabClientCustomerId;
  final String schwabClientCorrelId;
  final String schwabClientChannel;
  final String schwabClientFunctionId;

  const SchwabStreamerInfo({
    required this.streamerSocketUrl,
    required this.schwabClientCustomerId,
    required this.schwabClientCorrelId,
    required this.schwabClientChannel,
    required this.schwabClientFunctionId,
  });

  factory SchwabStreamerInfo.fromUserPreference(dynamic json) {
    if (json == null) {
      throw ArgumentError('JSON payload cannot be null');
    }

    dynamic info;
    if (json is Map<String, dynamic>) {
      if (json['streamerInfo'] is List &&
          (json['streamerInfo'] as List).isNotEmpty) {
        info = json['streamerInfo'][0];
      } else if (json['streamerInfo'] is Map<String, dynamic>) {
        info = json['streamerInfo'];
      } else {
        info = json;
      }
    } else if (json is List && json.isNotEmpty) {
      info = json[0];
    } else {
      info = json;
    }

    return SchwabStreamerInfo(
      streamerSocketUrl: (info['streamerSocketUrl'] ??
              info['streamerUrl'] ??
              'wss://streamer-api.schwab.com/ws')
          .toString(),
      schwabClientCustomerId:
          (info['schwabClientCustomerId'] ?? info['customerId'] ?? '')
              .toString(),
      schwabClientCorrelId:
          (info['schwabClientCorrelId'] ?? info['correlId'] ?? '').toString(),
      schwabClientChannel:
          (info['schwabClientChannel'] ?? info['channel'] ?? '').toString(),
      schwabClientFunctionId:
          (info['schwabClientFunctionId'] ?? info['functionId'] ?? '')
              .toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'streamerSocketUrl': streamerSocketUrl,
      'schwabClientCustomerId': schwabClientCustomerId,
      'schwabClientCorrelId': schwabClientCorrelId,
      'schwabClientChannel': schwabClientChannel,
      'schwabClientFunctionId': schwabClientFunctionId,
    };
  }

  @override
  String toString() {
    return 'SchwabStreamerInfo(url: $streamerSocketUrl, customer: $schwabClientCustomerId, correl: $schwabClientCorrelId, channel: $schwabClientChannel, func: $schwabClientFunctionId)';
  }
}
