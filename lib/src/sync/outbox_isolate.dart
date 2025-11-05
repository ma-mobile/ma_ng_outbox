import 'dart:convert';
import 'dart:io';
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

  final dio = Dio()
    ..options.headers = {
      'Authorization': 'Bearer ${payload.accessToken}',
    };

  for (final item in payload.items) {
    try {
      dynamic requestData;

      final hasFiles = item.filePathsJson != null &&
          item.filePathsJson!.isNotEmpty &&
          item.fileFieldsJson != null &&
          item.fileFieldsJson!.isNotEmpty;

      if (hasFiles) {
        // ✅ Decode file paths and field names
        final List filePaths = List<String>.from(jsonDecode(item.filePathsJson!));
        final List fileFields = List<String>.from(jsonDecode(item.fileFieldsJson!));

        final Map<String, dynamic> formMap = {};

        // ✅ Add string params (payload) to form
        if (item.payload != null) {
          final Map<String, dynamic> payloadMap = jsonDecode(item.payload!);
          formMap.addAll(payloadMap);
        }

        // ✅ Add each file with its corresponding field
        for (int i = 0; i < filePaths.length; i++) {
          final file = File(filePaths[i]);
          final field = fileFields[i];

          formMap[field] = await MultipartFile.fromFile(file.path);
        }

        requestData = FormData.fromMap(formMap);
      } else {
        // ✅ JSON request
        requestData = item.payload != null ? jsonDecode(item.payload!) : null;
      }

      final res = await dio.request(
        item.url,
        data: requestData,
        options: Options(
          method: item.operation,
          responseType: ResponseType.bytes, // handle binary, text & json
        ),
      );

      final normalized = normalizeResponse(res.data);

      payload.sendPort.send(OutboxIsolateResult(item.id, normalized));
    } catch (e) {
      payload.sendPort.send(OutboxIsolateResult(item.id, null));
    }
  }
}


