import 'dart:convert';
import 'package:dio/dio.dart';

import '../../../objectbox.g.dart';
import '../ma_ng_outbox.dart';

class ObjectBoxHelper {
  late final Store store;
  late final Box<OutboxItem> outboxBox;
  String refreshToken = '';
  String refreshTokenUrl = '';
  String clientId ='';
  String clientSecret ='';
  Dio? dio;

  static ObjectBoxHelper? _instance;

  ObjectBoxHelper._create(this.store) {
    outboxBox = store.box<OutboxItem>();
  }

  static Future<ObjectBoxHelper> create() async {
    if (_instance != null) return _instance!;
    final store = await openStore();
    _instance = ObjectBoxHelper._create(store);

    return _instance!;
  }

  Future<void> addToOutbox({
    required String operation,
    required String url,
    dynamic payload,
    Priority priority = Priority.medium,
    String? endPoint,
    String? primaryKey,
    Map<String, dynamic>? fieldsJson,
    String? tableId,
    List<String>? filePaths,
    List<String>? fileFields,
  }) async {
    final pk = primaryKey ?? 'local-${DateTime.now().millisecondsSinceEpoch}';

    // Convert request model to json string
    String? jsonString;
    if (payload != null) jsonString = jsonEncode(payload);

    String? fieldsJsonString;
    if (fieldsJson != null) {
      fieldsJsonString = jsonEncode(fieldsJson);   // <-- FIXED
    }

    OutboxItem? existing;

    if(tableId==null) {
      // 🔍 Check for an existing unsynced item with same PK + endpoint
      existing = outboxBox.query(
          OutboxItem_.isSynced.equals(0)
              .and(OutboxItem_.primaryKey.equals(pk))
              .and(OutboxItem_.endPoint.equals(endPoint ?? ""))
      ).build().findFirst();
    }
    else{
      existing = outboxBox.query(
          OutboxItem_.isSynced.equals(0)
              .and(OutboxItem_.primaryKey.equals(pk))
              .and(OutboxItem_.tableId.equals(tableId))
              .and(OutboxItem_.endPoint.equals(endPoint ?? ""))
      ).build().findFirst();
    }

    if (existing != null) {
      existing.priority = priority.priority;
      existing.fieldsJson = fieldsJsonString;
      existing.payload = jsonString;
      existing.filePathsJson = filePaths == null ? null : jsonEncode(filePaths);
      existing.fileFieldsJson = fileFields == null ? null : jsonEncode(fileFields);
      existing.createdAt = DateTime.now().millisecondsSinceEpoch;
      outboxBox.put(existing);
      print("🔁 Updated existing outbox item for primaryKey=$pk endPoint=$endPoint");
      return;
    }

    // 🟢 Otherwise insert a new one
    final item = OutboxItem(
      operation: operation,
      endPoint: endPoint,
      primaryKey: pk,
      priority: priority.priority,
      url: url,
      fieldsJson: fieldsJsonString,
      payload: jsonString,
      response: null,
      tableId: tableId,
      isSynced: 0,
      filePathsJson: filePaths == null ? null : jsonEncode(filePaths),
      fileFieldsJson: fileFields == null ? null : jsonEncode(fileFields),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    outboxBox.put(item);
    print("🆕 Added new outbox item for primaryKey=$pk endPoint=$endPoint");
  }

}
