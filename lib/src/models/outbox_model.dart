import 'package:objectbox/objectbox.dart';

@Entity()
class OutboxItem {
  @Id()
  int id;

  String operation;
  String? tableName;
  String? primaryKey;
  String url;
  String? payload;
  String? response;
  int retryCount;
  int lastTried;
  int isSynced;
  int createdAt;

  OutboxItem({
    this.id = 0,
    required this.operation,
    this.tableName,
    this.primaryKey,
    required this.url,
    this.payload,
    this.response,
    this.retryCount = 0,
    this.lastTried = 0,
    this.isSynced = 0,
    required this.createdAt,
  });
}
