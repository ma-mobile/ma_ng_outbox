📦 Offline Outbox Sync for Flutter (ObjectBox + Isolate + Retry + Multipart Support)

A powerful and lightweight offline-first outbox queue system for Flutter apps.
Designed for real-world enterprise use cases where network instability, large payloads, and token expiry must be handled automatically.

``` text
Supports:

    ✅ JSON API requests

    ✅ Multipart file uploads

    ✅ Multiple files per request

    ✅ Empty multipart field names

    ✅ Automatic retry with priority

    ✅ Automatic token refresh (401 handling)

    ✅ Runs in Isolate for non-blocking UI

    ✅ ObjectBox storage for fast persistence

    ✅ Fully background-safe
```


| Feature                                 | Status        |
|-----------------------------------------|---------------|
| JSON request outbox                     | ✅             |
| Multipart upload (files/images/docs)    | ✅             |
| Multiple files with dynamic field names | ✅             |
| Empty file field name ("") support      | ✅             |
| Priority-based queue (1 → 4)            | ✅             |
| Automatic retry on failures             | ✅             |
| Retry with new token on 401             | ✅             |
| Save status code + response             | ✅             |
| RootIsolateToken support                | ✅             |
| Zero UI freeze                          | Isolate-based |
| Production-ready                        | 🔥            |



📦 Installation

Add to pubspec.yaml:

```yaml
  dependencies:
    ma_ng_outbox: latest
```

Make sure ObjectBox is installed:

```yaml
  dependencies:
    objectbox: any
    objectbox_flutter_libs: any
```

🛠 Basic Setup
1️⃣ Initialize Outbox in main.dart

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OutboxBootstrap.setup();
  runApp(MyApp());
}

```

🧱 How Outbox Works

Every API call is stored as an OutboxItem:

```dart

await objectBox.addToOutbox(
  operation: "POST",
  url: "https://api.server.com/save",
  payload: {"title": "Offline Save"},
  priority: Priority.high,
  primaryKey: "local-123",
  filePathsJson: [''],
  fileFieldsJson: ['']
);


```

``` text
Then Outbox will:

    ✔ Automatically sync when online

    ✔ Retry failed requests

    ✔ Retry 401 using refresh token

    ✔ Save response & status code

    ✔ Process highest priority first
```

🧵 Architecture Overview

``` text
UI Layer ──► addToOutbox() ──► ObjectBox storage
                   │
                   ▼
          Background Sync Trigger
                   │
                   ▼
             Isolate Spawned
                   │
                   ▼
       outboxIsolateEntry() processing
                   │
   ├──► JSON Request
   ├──► Multipart Request
   ├──► Multi-file Upload
   └──► Retry on 401 (Refresh Token)
                   │
                   ▼
       Main Isolate receives result
                   │
                   ▼
   Updates ObjectBox (status + response)
```

📁 Adding File Upload Requests
⭐ One File

```dart
await objectBox.addToOutbox(
  operation: "POST",
  url: Api.uploadImage,
  payload: {
    "description": "Offline photo",
    "userId": 12,
  },
  filePathsJson: jsonEncode([imageFile.path]),
  fileFieldsJson: jsonEncode(["file"]), // or ""
);

```
⭐ Multiple Files
```dart
await objectBox.addToOutbox(
  operation: "POST",
  url: Api.uploadDocuments,
  payload: {"caseId": 55},
  filePathsJson: jsonEncode([frontPath, backPath]),
  fileFieldsJson: jsonEncode(["front", "back"]),
);

```


``` text
🔐 Token Refresh Flow (401 Handling)
    1.If API returns 401 Unauthorized:

    2.Outbox calls refresh token API

    3.Saves new access token to OutboxItem

    4.Retries the original request automatically

    5.Continues syncing

This is built-in.
```

🔄 Manual Triggering of Sync

```dart
SyncController.runIsolateSync(
  objectBox: objectBox,
  token: "<accessToken>",
  rootToken: rootToken,
);

```


``` text
🚀 Performance & Scaling

    * 25,000+ outbox items stress-tested

    * Large file uploads supported

    * Zero UI freeze due to isolate-based architecture

    * Perfect for enterprise offline-first apps


```