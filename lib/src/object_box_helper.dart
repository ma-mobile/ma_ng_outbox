import 'dart:convert';
import '../../../objectbox.g.dart';
import '../ma_ng_outbox.dart';

class ObjectBoxHelper {
  late final Store store;
  late final Box<OutboxItem> outboxBox;

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
    List<String>? filePaths,
    List<String>? fileFields,
  }) async {
    String? jsonString;
    if (payload != null) jsonString = jsonEncode(payload);

    final item = OutboxItem(
      operation: operation,
      endPoint: endPoint,
      primaryKey: primaryKey,
      priority: priority.priority,
      url: url,
      payload: jsonString,
      response: null,
      isSynced: 0,
      filePathsJson: filePaths==null ? null : jsonEncode(filePaths),
      fileFieldsJson: fileFields==null ? null : jsonEncode(fileFields),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    outboxBox.put(item);
  }
}
