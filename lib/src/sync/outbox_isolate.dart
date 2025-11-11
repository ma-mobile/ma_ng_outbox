import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
        dynamic decodedPaths;
        dynamic decodedFields;

        try {
          decodedPaths = jsonDecode(item.filePathsJson ?? "[]");
        } catch (_) {
          decodedPaths = [];
        }

        try {
          decodedFields = jsonDecode(item.fileFieldsJson ?? "[]");
        } catch (_) {
          decodedFields = [];
        }

        final List<String> filePaths =
        decodedPaths is List ? List<String>.from(decodedPaths) : [];
        final List<String> fileFields =
        decodedFields is List ? List<String>.from(decodedFields) : [];

        final formData = FormData();

        // ✅ Add payload fields
        if (item.payload != null && item.payload!.isNotEmpty) {
          final Map<String, dynamic> payloadMap = jsonDecode(item.payload!);
          payloadMap.forEach((k, v) => formData.fields.add(MapEntry(k, v.toString())));
        }

        // ✅ Add files (safe even if empty)
        for (int i = 0; i < filePaths.length; i++) {
          final filePath = filePaths[i];
          final fieldName = i < fileFields.length ? fileFields[i] : "";
          if (File(filePath).existsSync()) {
            final multipartFile = await MultipartFile.fromFile(filePath);
            formData.files.add(MapEntry(fieldName, multipartFile));
          }
        }

        requestData = formData;
      } else {
        requestData =
        item.payload != null && item.payload!.isNotEmpty ? jsonDecode(item.payload!) : null;
      }

      final method = item.operation.toUpperCase();

      Response res;

      if (kDebugMode) {
        print("🚀 [Outbox] Sending ${item.operation} → ${item.url}");
        print("🟡 Headers: ${dio.options.headers}");
        print("🟡 Payload: ${requestData is FormData ? 'FormData' : requestData
            .runtimeType}");
        if (requestData is FormData) {
          print("🟣 Form fields: ${requestData.fields}");
          print(
              "🟣 File fields: ${requestData.files.map((e) => e.key).toList()}");
        } else {
          print("🟣 Body: ${jsonEncode(requestData)}");
        }
      }
      switch (method) {
        case "POST":
          res = await dio.post(item.url, data: requestData ?? {});
        case "PUT":
          res = await dio.put(item.url, data: requestData ?? {});
        case "DELETE":
          res = await dio.delete(item.url, data: requestData ?? {});
        default:
          res = await dio.get(item.url, queryParameters: requestData);
      }

      final normalized = normalizeResponse(res.data);

      payload.sendPort.send(OutboxIsolateResult(item.id, normalized));
    } catch (e, st) {
      // In case of error, send null but log internally
      print("❌ Outbox isolate error for ID ${item.id}: $e");
      print(st);
      payload.sendPort.send(OutboxIsolateResult(item.id, null));
    }
  }
}



