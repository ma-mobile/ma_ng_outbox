// You have generated a new plugin project without specifying the `--platforms`
// flag. A plugin project with no platform support was generated. To add a
// platform, run `flutter create -t plugin --platforms <platforms> .` under the
// same directory. You can also find a detailed instruction on how to add
// platforms in the `pubspec.yaml` at
// https://flutter.dev/to/pubspec-plugin-platforms.
library ma_ng_outbox;
import 'ma_ng_outbox_platform_interface.dart';
export 'src/object_box_helper.dart';
export 'src/models/outbox_model.dart';
export 'src/sync/outbox_sync_worker.dart';
export 'src/sync/outbox_isolate.dart';
export 'src/sync/sync_controller.dart';
export 'src/network/connectivity_service.dart';
export 'src/sync/outbox_sync_listener.dart';


class MaNgOutbox {
  Future<String?> getPlatformVersion() {
    return MaNgOutboxPlatform.instance.getPlatformVersion();
  }
}
