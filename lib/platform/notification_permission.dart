import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum NotificationPermissionState { notRequired, granted, denied, unavailable }

abstract interface class NotificationPermissionGateway {
  Future<NotificationPermissionState> request();
}

class MethodChannelNotificationPermissionGateway
    implements NotificationPermissionGateway {
  factory MethodChannelNotificationPermissionGateway({
    MethodChannel channel = const MethodChannel(
      'app.pathgrain/notification_permission',
    ),
  }) {
    return MethodChannelNotificationPermissionGateway._(channel);
  }

  MethodChannelNotificationPermissionGateway._(this._channel);

  final MethodChannel _channel;

  @override
  Future<NotificationPermissionState> request() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return NotificationPermissionState.notRequired;
    }

    try {
      final result = await _channel.invokeMethod<String>('request');
      return switch (result) {
        'notRequired' => NotificationPermissionState.notRequired,
        'granted' => NotificationPermissionState.granted,
        'denied' => NotificationPermissionState.denied,
        _ => NotificationPermissionState.unavailable,
      };
    } on PlatformException {
      return NotificationPermissionState.unavailable;
    } on MissingPluginException {
      return NotificationPermissionState.unavailable;
    }
  }
}
