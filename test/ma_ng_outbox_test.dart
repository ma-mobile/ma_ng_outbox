import 'package:flutter_test/flutter_test.dart';
import 'package:ma_ng_outbox/ma_ng_outbox.dart';
import 'package:ma_ng_outbox/ma_ng_outbox_platform_interface.dart';
import 'package:ma_ng_outbox/ma_ng_outbox_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMaNgOutboxPlatform
    with MockPlatformInterfaceMixin
    implements MaNgOutboxPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final MaNgOutboxPlatform initialPlatform = MaNgOutboxPlatform.instance;

  test('$MethodChannelMaNgOutbox is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelMaNgOutbox>());
  });

  test('getPlatformVersion', () async {
    MaNgOutbox maNgOutboxPlugin = MaNgOutbox();
    MockMaNgOutboxPlatform fakePlatform = MockMaNgOutboxPlatform();
    MaNgOutboxPlatform.instance = fakePlatform;

    expect(await maNgOutboxPlugin.getPlatformVersion(), '42');
  });
}
