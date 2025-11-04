import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../objectbox.g.dart';
import '../../ma_ng_outbox.dart';

class OutboxSyncWorker {
  final Store store;
  final Box<OutboxItem> outboxBox;
  final Dio dio;

  OutboxSyncWorker._(this.store, this.outboxBox, this.dio);

  static Future<OutboxSyncWorker> create(Store store) async {
    final outboxBox = store.box<OutboxItem>();
    final dio = Dio();

    return OutboxSyncWorker._(store, outboxBox, dio);
  }

  Future<void> processOutbox(String token) async {
    dio.options.headers = { 'Authorization': 'Bearer $token' };

    final query = outboxBox.query(OutboxItem_.isSynced.equals(0))
        .order(OutboxItem_.createdAt)
        .build();

    final items = query.find();
    query.close();

    for (final item in items) {
      try {
        final res = await dio.request(
          item.url,
          data: item.payload != null ? jsonDecode(item.payload!) : null,
          options: Options(
              method: item.operation,
            responseType: ResponseType.bytes,
          ),
        );

        if (res.statusCode == 200) {
          item.response = jsonEncode(res.data);
          item.isSynced = 1;
          outboxBox.put(item);
        }

      } catch (e) {
        item.retryCount++;
        item.lastTried = DateTime.now().millisecondsSinceEpoch;
        outboxBox.put(item);
      }
    }
  }




}

/// Detect response type and normalize to safe String storage.
String normalizeResponse(dynamic data) {
  // ✅ Case 1: If raw bytes → convert to Base64
  if (data is List<int>) {
    return base64Encode(data);
  }

  // ✅ Case 2: If response is already String
  if (data is String) {
    final s = data.trim();

    // ✅ Check JSON object/array
    if ((s.startsWith('{') && s.endsWith('}')) ||
        (s.startsWith('[') && s.endsWith(']'))) {
      return s; // valid JSON string
    }

    // ✅ Check Base64
    final base64Regex = RegExp(r'^[A-Za-z0-9+/=]+$');
    if (base64Regex.hasMatch(s)) {
      return s; // assume Base64
    }

    // ✅ Otherwise plain text
    return s;
  }

  // ✅ Case 3: If JSON object (Map or List)
  if (data is Map || data is List) {
    return jsonEncode(data);
  }

  // ✅ Fallback: Convert to string
  return data.toString();
}
