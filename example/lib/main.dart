import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ Needed for RootIsolateToken
import 'package:ma_ng_outbox/ma_ng_outbox.dart';

import 'home_page.dart';

late ObjectBoxHelper objectBox;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize ObjectBox once in main isolate
  objectBox = await ObjectBoxHelper.create();

  // ✅ Capture Root Isolate Token (required for isolates using plugins)
  final RootIsolateToken rootToken = ServicesBinding.rootIsolateToken!;

  // ✅ Global network listener
  ConnectivityService().onNetworkChange.listen((isOnline) async {
    if (isOnline && GlobalAccessTokenHolder.token != null) {
      debugPrint("🌐 Network available → Sync starting...");

      // ✅ Trigger isolate sync with RootIsolateToken
      await SyncController.runIsolateSync(
        token: GlobalAccessTokenHolder.token!,
        rootToken: rootToken,
        objectBox: objectBox
      );
    }else{
      debugPrint("🌐 Network not available → Sync Paused...");
    }
  });

  // ✅ Example (replace with your login logic)
  GlobalAccessTokenHolder.token = """fghefg""";

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    ),
  );

}

class GlobalAccessTokenHolder {
  static String? token;
}

