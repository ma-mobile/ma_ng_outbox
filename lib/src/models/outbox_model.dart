import 'package:objectbox/objectbox.dart';

@Entity()
class OutboxItem {
  @Id()
  int id;

  String operation;
  String? endPoint;
  String? primaryKey;
  String url;
  int priority;
  String? payload;
  String? response;
  int retryCount;
  int lastTried;
  int isSynced;
  int createdAt;
  String? filePathsJson;
  String? fileFieldsJson;

  /// Priority 1 is lowest
  /// Priority 2 is medium
  /// Priority 3 is high
  /// Priority 4 is very high

  OutboxItem({
    this.id = 0,
    required this.operation,
    this.endPoint,
    this.primaryKey,
    required this.url,
    this.payload,
    this.response,
    this.retryCount = 0,
    this.priority = 2,
    this.lastTried = 0,
    this.isSynced = 0,
    this.fileFieldsJson,
    this.filePathsJson,
    required this.createdAt,
  });
}


enum Priority {
  lowest(priority: 1),
  medium(priority: 2),
  high(priority: 3),
  veryHigh(priority: 4);


  final int priority;

  const Priority({required this.priority});
}
