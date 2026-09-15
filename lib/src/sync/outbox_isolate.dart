import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final String certificatesDirectory;
  final String pfxPassword;

  OutboxIsolatePayload(
    this.items,
    this.accessToken,
    this.rootToken,
    this.sendPort,
    this.refreshToken,
    this.refreshTokenUrl,
    this.clientId,
    this.clientSecret,
    this.certificatesDirectory,
    this.pfxPassword,
  );
}

class OutboxIsolateResult {
  final int id;
  final String? response;
  final int statusCode;
  final String? newAccessToken;

  OutboxIsolateResult(
    this.id,
    this.response,
    this.statusCode,
    this.newAccessToken,
  );
}

void outboxIsolateEntry(OutboxIsolatePayload payload) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(payload.rootToken);

  print("✅ Outbox Isolate Entry v3.0");

  final dio = Dio()
    ..options.headers = {'Authorization': 'Bearer ${payload.accessToken}'};

  if (payload.certificatesDirectory.isNotEmpty) {
    try {
      dio.httpClientAdapter = await SecureClient.createAdapter(
        certDir: payload.certificatesDirectory,
        bundlePassword: payload.pfxPassword.isEmpty
            ? null
            : payload.pfxPassword,
      );
      print('✅ Custom TLS adapter applied');
    } catch (e) {
      print('⚠️ Falling back to default TLS: $e');
    }
  }

  for (final item in payload.items) {
    try {
      dynamic requestData;

      // ---------- DECODE ARRAYS ----------
      List<String> filePaths = [];
      List<String> fileFields = [];
      Map<String, dynamic> extraFields = {}; // <-- fieldsJson

      if (item.filePathsJson != null) {
        try {
          filePaths = List<String>.from(jsonDecode(item.filePathsJson!));
        } catch (_) {}
      }

      if (item.fileFieldsJson != null) {
        try {
          fileFields = List<String>.from(jsonDecode(item.fileFieldsJson!));
        } catch (_) {}
      }

      if (item.fieldsJson != null) {
        try {
          extraFields = Map<String, dynamic>.from(jsonDecode(item.fieldsJson!));
        } catch (_) {}
      }

      final bool needMultipart = filePaths.isNotEmpty || extraFields.isNotEmpty;

      Options? requestOptions;
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
        print('=== FILES ===');
        print('${filePaths.toString()}');
        print('=== FILES ===');
        print('=== FILE FIELDS ===');
        print('${fileFields.toString()}');
        print('=== FILE FIELDS ===');
        for (int i = 0; i < filePaths.length; i++) {
          final path = filePaths[i];
          final fieldName = (i < fileFields.length && fileFields[i].isNotEmpty)
              ? fileFields[i]
              : "file";
          final fileExist = await File(path).exists();
          print('=== FILE EXIST $fileExist ===');
          if (File(path).existsSync()) {
            formData.files.add(
              MapEntry(fieldName, await MultipartFile.fromFile(path)),
            );
          }
        }

        requestData = formData;
        requestOptions = Options(
          contentType: Headers.multipartFormDataContentType,
        );
        print('=== FORMDATA FIELDS ===');
        for (var field in formData.fields) {
          print('Key: ${field.key} | Value: ${field.value}');
        }

        print('=== FORMDATA FILES ===');
        for (var file in formData.files) {
          print('Field Name: ${file.key}');
          print('File Name: ${file.value.filename}');
          print('Content Type: ${file.value.contentType}');
          print('Length: ${file.value.length} bytes');
        }
        print('=========================');
      }
      // ---------- RAW JSON REQUEST ----------
      else {
        requestData = (item.payload != null && item.payload!.isNotEmpty)
            ? jsonDecode(item.payload!)
            : null;
        requestOptions = Options(contentType: Headers.jsonContentType);
      }

      // ---------- SEND API REQUEST ----------
      Response res;

      switch (item.operation.toUpperCase()) {
        case 'POST':
          res = await dio.post(
            item.url,
            data: requestData,
            options: requestOptions,
          );
          print("Res = > ${res.data} with ${res.statusCode}");
          break;
        case 'PUT':
          res = await dio.put(
            item.url,
            data: requestData,
            options: requestOptions,
          );
          break;
        case 'DELETE':
          res = await dio.delete(
            item.url,
            data: requestData,
            options: requestOptions,
          );
          break;
        default:
          res = await dio.get(
            item.url,
            queryParameters: requestData,
            options: requestOptions,
          );
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
      if (e is DioException) {
        print('🚨 DIO ERROR STATUS: ${e.response?.statusCode}');
        print(
          '🚨 DIO ERROR DATA: ${e.response?.data}',
        ); // <-- This will tell you the exact problem!
      } else {
        print('🚨 UNKNOWN ERROR: $e');
      }
      payload.sendPort.send(OutboxIsolateResult(item.id, null, 0, null));
    }
  }

  payload.sendPort.send("__CLOSE__");
}

Future<String?> refreshAccessToken(
  String refreshTokenUrl,
  String refreshToken,
  String clientId,
  String clientSecret,
) async {
  try {
    final url = Uri.parse(refreshTokenUrl);

    // final headers = {'Content-Type': 'application/x-www-form-urlencoded'};

    final body = {
      'grant_type': 'refresh_token',
      'client_id': clientId,
      'client_secret': clientSecret,
      'refresh_token': refreshToken,
      'scope': 'openid profile api1 offline_access',
    };

    final res = await HttpClient().postUrl(url).then((req) {
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

class SecureClient {
  const SecureClient._();

  static const defaultCertDir = '/storage/emulated/0/Certificates';

  static const _caExtensions = {'.cer', '.crt', '.pem'};
  static const _bundleExtensions = {'.pfx', '.p12'};

  static const _minCertBytes = 32;

  static Future<IOHttpClientAdapter> createAdapter({
    String certDir = defaultCertDir,
    String? bundlePassword,
    bool trustPublicRoots = true,
  }) async {
    final scan = await scanDirectory(certDir);

    if (scan.caPems.isEmpty) {
      throw StateError('No usable CA certificate found in $certDir. ');
    }

    final caPem = _concatPems(scan.caPems);

    try {
      SecurityContext(
        withTrustedRoots: false,
      ).setTrustedCertificatesBytes(caPem);
    } on TlsException catch (e) {
      throw StateError('CA certificates in $certDir are invalid: ${e.message}');
    }

    final bundleBytes = scan.clientBundle;

    return IOHttpClientAdapter(
      createHttpClient: () {
        final ctx = SecurityContext(withTrustedRoots: trustPublicRoots);
        ctx.setTrustedCertificatesBytes(caPem);

        if (bundleBytes != null) {
          ctx.useCertificateChainBytes(bundleBytes, password: bundlePassword);
          ctx.usePrivateKeyBytes(bundleBytes, password: bundlePassword);
        }

        return HttpClient(context: ctx);
      },
    );
  }

  static Future<ScanResult> scanDirectory(String certDir) async {
    final dir = Directory(certDir);
    if (!await dir.exists()) {
      throw StateError('Certificate directory not found: $certDir');
    }

    final caPems = <Uint8List>[];
    final skipped = <String>[];
    Uint8List? clientBundle;
    var inspected = 0;

    final entries = await dir.list(followLinks: false).toList();
    entries.sort((a, b) => a.path.compareTo(b.path)); // deterministic order

    for (final entry in entries) {
      if (entry is! File) continue;

      final name = entry.path.split('/').last;
      debugPrint('name : $name');
      final ext = _extensionOf(name);
      debugPrint('ext : $ext');

      final isCa = _caExtensions.contains(ext);
      final isBundle = _bundleExtensions.contains(ext);
      if (!isCa && !isBundle) continue;

      inspected++;

      try {
        final bytes = await entry.readAsBytes();
        if (bytes.length < _minCertBytes) {
          skipped.add('$name (empty or truncated)');
          continue;
        }

        if (isBundle) {
          clientBundle ??= bytes;
          continue;
        }

        caPems.add(_toPem(bytes));
      } on FormatException catch (e) {
        skipped.add('$name (${e.message})');
      } on FileSystemException catch (e) {
        skipped.add('$name (unreadable: ${e.message})');
      }
    }

    debugPrint("caPems: ${caPems.length}");
    debugPrint("clientBundle: ${clientBundle.toString()}");

    return ScanResult(
      caPems: caPems,
      clientBundle: clientBundle,
      inspected: inspected,
      skipped: skipped,
    );
  }

  static String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    return dot == -1 ? '' : name.substring(dot).toLowerCase();
  }

  static Uint8List _concatPems(List<Uint8List> pems) {
    final buffer = StringBuffer();
    for (final pem in pems) {
      final text = utf8.decode(pem, allowMalformed: true);
      buffer.write(text);
      if (!text.endsWith('\n')) buffer.writeln();
    }
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  static Uint8List _toPem(Uint8List bytes) {
    final head = utf8.decode(
      bytes.sublist(0, bytes.length < 11 ? bytes.length : 11),
      allowMalformed: true,
    );

    if (head.contains('-----BEGIN')) {
      final raw = utf8.decode(bytes, allowMalformed: true).replaceAll('\r', '');

      final buffer = StringBuffer();
      var inBlock = false;
      for (final line in const LineSplitter().convert(raw)) {
        if (line.startsWith('-----BEGIN')) inBlock = true;
        if (inBlock) buffer.writeln(line);
        if (line.startsWith('-----END')) inBlock = false;
      }

      if (buffer.isEmpty) {
        throw const FormatException('no PEM block found');
      }
      return Uint8List.fromList(utf8.encode(buffer.toString()));
    }

    if (bytes.length < 2 || bytes[0] != 0x30 || (bytes[1] & 0x80) == 0) {
      throw const FormatException('not a PEM or DER X.509 certificate');
    }

    final b64 = base64.encode(bytes);
    final lines = <String>[];
    for (var i = 0; i < b64.length; i += 64) {
      lines.add(b64.substring(i, i + 64 > b64.length ? b64.length : i + 64));
    }

    return Uint8List.fromList(
      utf8.encode(
        '-----BEGIN CERTIFICATE-----\n'
        '${lines.join('\n')}\n'
        '-----END CERTIFICATE-----\n',
      ),
    );
  }
}

class ScanResult {
  final List<Uint8List> caPems;
  final Uint8List? clientBundle;
  final int inspected;
  final List<String> skipped;

  const ScanResult({
    required this.caPems,
    required this.clientBundle,
    required this.inspected,
    required this.skipped,
  });

  bool get hasClientIdentity => clientBundle != null;
}
