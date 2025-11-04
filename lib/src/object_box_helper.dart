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

    // final dir = await getApplicationDocumentsDirectory();
    // final store = await openStore(directory: '${dir.path}/objectBox');
    final store = await openStore();
    _instance = ObjectBoxHelper._create(store);

    return _instance!;
  }

  Future<void> addToOutbox({
    required String operation,
    required String url,
    dynamic payload,
    String? tableName,
    String? primaryKey,
  }) async {
    String? jsonString;
    if (payload != null) jsonString = jsonEncode(payload);

    final item = OutboxItem(
      operation: operation,
      tableName: tableName,
      primaryKey: primaryKey,
      url: url,
      payload: jsonString,
      response: null,
      isSynced: 0,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    outboxBox.put(item);
  }
}
