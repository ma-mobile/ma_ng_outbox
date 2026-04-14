import 'dart:async';

import 'package:ma_ng_outbox/ma_ng_outbox.dart';

// 1. Create a model to hold the data you want to send to the UI
class OutboxSyncEvent {
  final OutboxItem outboxItem;

  OutboxSyncEvent({
    required this.outboxItem
  });
}

// 2. Create a global/static Broadcast StreamController
class OutboxNotifier {
  static final StreamController<OutboxSyncEvent> _syncEventController =
  StreamController<OutboxSyncEvent>.broadcast();

  // Your apps will listen to this stream
  static Stream<OutboxSyncEvent> get onSyncComplete => _syncEventController.stream;

  // Internal method to add events
  static void notify(OutboxSyncEvent event) {
    _syncEventController.add(event);
  }
}