import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ma_ng_outbox_platform_interface.dart';

/// An implementation of [MaNgOutboxPlatform] that uses method channels.
class MethodChannelMaNgOutbox extends MaNgOutboxPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('ma_ng_outbox');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
