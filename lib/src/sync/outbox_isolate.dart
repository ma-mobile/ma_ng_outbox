import 'dart:convert';
import 'dart:isolate';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart'; // ✅ Required!
import '../../ma_ng_outbox.dart';

class OutboxIsolatePayload {
  final List<OutboxItem> items;
  final String accessToken;
  final RootIsolateToken rootToken;
  final SendPort sendPort;

  OutboxIsolatePayload(this.items, this.accessToken, this.rootToken, this.sendPort);
}

class OutboxIsolateResult {
  final int id;
  final String? response;

  OutboxIsolateResult(this.id, this.response);
}


void outboxIsolateEntry(OutboxIsolatePayload payload) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(payload.rootToken);

  final dio = Dio()..options.headers = {
    'Authorization': 'Bearer ${payload.accessToken}',
  };

  for (final item in payload.items) {
    try {
      final res = await dio.request(
        item.url,
        data: item.payload != null ? jsonDecode(item.payload!) : null,
        options: Options(
            method: item.operation,
          responseType: ResponseType.bytes
        ),
      );

      String normalized = normalizeResponse(res.data);

      payload.sendPort.send(
        OutboxIsolateResult(item.id, normalized),
      );

      payload.sendPort.send(
        OutboxIsolateResult(item.id, res.data),
      );

    } catch (_) {
      payload.sendPort.send(
        OutboxIsolateResult(item.id, null),
      );
    }
  }
}

