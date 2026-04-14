import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:ma_ng_outbox/src/sync/outbox_sync_listener.dart';

import '../../ma_ng_outbox.dart';
import '../../objectbox.g.dart';

class SyncController {
  static bool isSyncing = false;

  static Future<void> runIsolateSync({
    required ObjectBoxHelper objectBox,
    required String token,
    required RootIsolateToken rootToken,
    String? primaryKey,
    String? endPoint,
  }) async {
    if (isSyncing) {
      print("⏳ SKIPPED — sync already running");
      return;
    }

    isSyncing = true;
    print("🚀 Sync started");
    final box = objectBox.outboxBox;
    final refreshToken = objectBox.refreshToken;
    final refreshTokenUrl = objectBox.refreshTokenUrl;
    final clientId = objectBox.clientId;
    final clientSecret = objectBox.clientSecret;

    List<OutboxItem> items = [];
    if (primaryKey == null && endPoint == null) {
      items = box
          .query(OutboxItem_.isSynced.equals(0))
          .order(OutboxItem_.priority, flags: Order.descending)
          .order(OutboxItem_.createdAt)
          .build()
          .find();
    } else if (primaryKey != null && endPoint == null) {
      items = box
          .query(
            OutboxItem_.isSynced
                .equals(0)
                .and(OutboxItem_.primaryKey.equals(primaryKey)),
          )
          .order(OutboxItem_.priority, flags: Order.descending)
          .order(OutboxItem_.createdAt)
          .build()
          .find();
    } else if (primaryKey != null && endPoint != null) {
      items = box
          .query(
            OutboxItem_.isSynced
                .equals(0)
                .and(OutboxItem_.primaryKey.equals(primaryKey))
                .and(OutboxItem_.endPoint.equals(endPoint)),
          )
          .order(OutboxItem_.priority, flags: Order.descending)
          .order(OutboxItem_.createdAt)
          .build()
          .find();
    }

    final receivePort = ReceivePort();

    Isolate.spawn(
      outboxIsolateEntry,
      OutboxIsolatePayload(
        items,
        token,
        rootToken,
        receivePort.sendPort,
        refreshToken,
        refreshTokenUrl,
        clientId,
        clientSecret,
      ),
    );

    final sub = receivePort.listen((msg) {
      if (msg == "__CLOSE__") {
        print("👋 isolate says finished");
        receivePort.close();
        return;
      }

      if (msg is OutboxIsolateResult) {
        final item = box.get(msg.id);
        if (item == null) return;

        if (msg.newAccessToken != null) {
          item.newAccessToken = msg.newAccessToken;
        }

        item.statusCode = msg.statusCode;
        final bool isSuccess = msg.statusCode >= 200 && msg.statusCode < 300;
        if (isSuccess) {
          item.response = msg.response;
          item.isSynced = 1;
        }

        item.retryCount++;
        item.lastTried = DateTime.now().millisecondsSinceEpoch;

        box.put(item);
        if (isSuccess) {
          OutboxNotifier.notify(OutboxSyncEvent(outboxItem: item));
        }
      }
    });

    sub.onDone(() {
      print("🏁 Sync done + listener closed");
      isSyncing = false;
    });
  }
}
