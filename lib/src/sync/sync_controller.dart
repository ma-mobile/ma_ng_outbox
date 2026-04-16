import 'dart:isolate';

import 'package:flutter/services.dart';

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
    List<OutboxItem> Function(List<OutboxItem> pendingItems)? queueInterceptor,
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
    var queryBuilder = box.query(OutboxItem_.isSynced.equals(0));

    // 2. Dynamically add the Primary Key condition if it exists
    if (primaryKey != null && endPoint == null) {
      queryBuilder = box.query(
        OutboxItem_.isSynced
            .equals(0)
            .and(OutboxItem_.primaryKey.equals(primaryKey)),
      );
    } else if (primaryKey == null && endPoint != null) {
      // 🚨 This was your missing scenario!
      queryBuilder = box.query(
        OutboxItem_.isSynced
            .equals(0)
            .and(OutboxItem_.endPoint.equals(endPoint)),
      );
    } else if (primaryKey != null && endPoint != null) {
      queryBuilder = box.query(
        OutboxItem_.isSynced
            .equals(0)
            .and(OutboxItem_.primaryKey.equals(primaryKey))
            .and(OutboxItem_.endPoint.equals(endPoint)),
      );
    }

    // 3. Apply the sorting and build it once
    List<OutboxItem> items = queryBuilder
        .order(OutboxItem_.priority, flags: Order.descending)
        .order(OutboxItem_.createdAt)
        .build()
        .find();

    // 🚨 2. Pass the items to the host app's interceptor (if they provided one)
    List<OutboxItem> itemsReadyToSend = items;

    if (queueInterceptor != null) {
      itemsReadyToSend = queueInterceptor(items);
    }

    // 3. Stop if the host app filtered everything out
    if (itemsReadyToSend.isEmpty) {
      print("🏁 No ready items to sync.");
      isSyncing = false;
      return;
    }

    final receivePort = ReceivePort();

    Isolate.spawn(
      outboxIsolateEntry,
      OutboxIsolatePayload(
        itemsReadyToSend,
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
