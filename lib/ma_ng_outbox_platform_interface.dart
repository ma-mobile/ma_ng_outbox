import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ma_ng_outbox_method_channel.dart';

abstract class MaNgOutboxPlatform extends PlatformInterface {
  /// Constructs a MaNgOutboxPlatform.
  MaNgOutboxPlatform() : super(token: _token);

  static final Object _token = Object();

  static MaNgOutboxPlatform _instance = MethodChannelMaNgOutbox();

  /// The default instance of [MaNgOutboxPlatform] to use.
  ///
  /// Defaults to [MethodChannelMaNgOutbox].
  static MaNgOutboxPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [MaNgOutboxPlatform] when
  /// they register themselves.
  static set instance(MaNgOutboxPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
