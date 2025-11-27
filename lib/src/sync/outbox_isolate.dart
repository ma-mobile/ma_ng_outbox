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
  final String refreshToken;
  final String refreshTokenUrl;
  final String clientId;
  final String clientSecret;

  OutboxIsolatePayload(this.items, this.accessToken, this.rootToken, this.sendPort,this.refreshToken,this.refreshTokenUrl,this.clientId,this.clientSecret);
}

class OutboxIsolateResult {
  final int id;
  final String? response;
  final int statusCode;
  final String? newAccessToken;

  OutboxIsolateResult(this.id, this.response,this.statusCode,this.newAccessToken);
}


void outboxIsolateEntry(OutboxIsolatePayload payload) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(payload.rootToken);

  print("✅ Outbox Isolate Entry");

  final dio = Dio()
    ..options.headers = {
      'Authorization': 'Bearer ${payload.accessToken}',
    };

  for (final item in payload.items) {
    try {
      dynamic requestData;

      // ---------- DECODE ARRAYS ----------
      List<String> filePaths = [];
      List<String> fileFields = [];
      Map<String, dynamic> extraFields = {};   // <-- fieldsJson

      if (item.filePathsJson != null) {
        try { filePaths = List<String>.from(jsonDecode(item.filePathsJson!)); }
        catch (_) {}
      }

      if (item.fileFieldsJson != null) {
        try { fileFields = List<String>.from(jsonDecode(item.fileFieldsJson!)); }
        catch (_) {}
      }

      if (item.fieldsJson != null) {
        try { extraFields = Map<String, dynamic>.from(jsonDecode(item.fieldsJson!)); }
        catch (_) {}
      }

      final bool needMultipart =
          filePaths.isNotEmpty || extraFields.isNotEmpty;

      // ---------- MULTIPART REQUEST ----------
      if (needMultipart) {
        print("I am in multipart");
        final formData = FormData();

        // ADD ATTACHMENTLIST, TIMESTAMP, ETC.
        extraFields.forEach((key, value) {
          formData.fields.add(MapEntry(key, value.toString()));
        });

        // ADD PAYLOAD FIELDS
        if (item.payload != null && item.payload!.isNotEmpty) {
          final Map<String, dynamic> payloadMap = jsonDecode(item.payload!);
          payloadMap.forEach((k, v) {
            formData.fields.add(MapEntry(k, v.toString()));
          });
        }

        // ADD FILES
        for (int i = 0; i < filePaths.length; i++) {
          final path = filePaths[i];
          final fieldName = (i < fileFields.length && fileFields[i].isNotEmpty)
              ? fileFields[i]
              : "file";

          if (File(path).existsSync()) {
            formData.files.add(
              MapEntry(
                fieldName,
                await MultipartFile.fromFile(path),
              ),
            );
          }
        }

        requestData = formData;
      }

      // ---------- RAW JSON REQUEST ----------
      else {
        requestData =
        (item.payload != null && item.payload!.isNotEmpty)
            ? jsonDecode(item.payload!)
            : null;
      }

      // ---------- SEND API REQUEST ----------
      Response res;

      switch (item.operation.toUpperCase()) {
        case 'POST':
          res = await dio.post(item.url, data: requestData);
          print("Res = > ${res.data} with ${res.statusCode}");
          break;
        case 'PUT':
          res = await dio.put(item.url, data: requestData);
          break;
        case 'DELETE':
          res = await dio.delete(item.url, data: requestData);
          break;
        default:
          res = await dio.get(item.url, queryParameters: requestData);
      }

      payload.sendPort.send(
        OutboxIsolateResult(
          item.id,
          normalizeResponse(res.data),
          res.statusCode ?? 200,
          null,
        ),
      );
    }

    // ---------- ERROR HANDLING ----------
    catch (e) {
      payload.sendPort.send(
        OutboxIsolateResult(item.id, null, 0, null),
      );
    }
  }

  payload.sendPort.send("__CLOSE__");
}



Future<String?> refreshAccessToken(String refreshTokenUrl, String refreshToken,String clientId,String clientSecret) async {
  try {
    final url = Uri.parse(refreshTokenUrl);

    // final headers = {'Content-Type': 'application/x-www-form-urlencoded'};

    final body = {
      'grant_type': 'refresh_token',
      'client_id': clientId,
      'client_secret': clientSecret,
      'refresh_token': refreshToken,
      'scope': 'openid profile api1 offline_access'
    };

    final res = await HttpClient()
        .postUrl(url)
        .then((req) {
      req.headers.set("Content-Type", "application/x-www-form-urlencoded");
      req.write(Uri(queryParameters: body).query);
      return req.close();
    });

    final string = await res.transform(utf8.decoder).join();

    if (res.statusCode == 200) {
      final jsonBody = jsonDecode(string);
      return jsonBody["access_token"];
    }

    return null;
  } catch (e) {
    print("❌ Refresh Token Error: $e");
    return null;
  }
}

