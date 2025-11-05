import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/services.dart';
import '../../ma_ng_outbox.dart';
import '../../objectbox.g.dart';
import 'outbox_isolate.dart';

class SyncController {
  static Future<void> runIsolateSync({
    required ObjectBoxHelper objectBox,
    required String token,
    required RootIsolateToken rootToken,
  }) async {
    final box = objectBox.outboxBox;

    final items = box.query(OutboxItem_.isSynced.equals(0))
        .order(OutboxItem_.priority , flags: Order.descending)
        .order(OutboxItem_.createdAt)
        .build()
        .find();

    final receivePort = ReceivePort();

    Isolate.spawn(
      outboxIsolateEntry,
      OutboxIsolatePayload(items, token, rootToken, receivePort.sendPort),
    );

    receivePort.listen((msg) {
      if (msg is OutboxIsolateResult) {
        final item = box.get(msg.id);
        if (item != null) {
          if (msg.response != null) {
            item.response = jsonEncode(msg.response);
            item.isSynced = 1;
          }
          item.retryCount++;
          item.lastTried = DateTime.now().millisecondsSinceEpoch;
          box.put(item);
        }
      }
    });
  }
}


