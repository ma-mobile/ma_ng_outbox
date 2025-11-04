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
  GlobalAccessTokenHolder.token = "eyJhbGciOiJSUzI1NiIsImtpZCI6IjREQjc0M0QxNjFGQUM4NDEzNkZFQzc4OUM1MzBCRjM1IiwidHlwIjoiSldUIn0.eyJpc3MiOiJodHRwczovL3BhbG5nLXFhLXZzbC5tYXJpYXBwcy5jb20vaWRlbnRpdHlzZXJ2ZXIiLCJuYmYiOjE3NjIxNzU5MTAsImlhdCI6MTc2MjE3NTkxMCwiZXhwIjoxNzYyMjYyMzEwLCJhdWQiOiJwYWxOR1dlYiIsImFtciI6WyJwd2QiXSwibm9uY2UiOiI0NDRmYmM1NWZhZTA4N2ZmMDliOGQzNzYzZmVjM2FkZDQ4eWtONlI1VCIsImF0X2hhc2giOiJEWnVxVmJyNnNIZndKX2lFelhVTkJnIiwic2lkIjoiRDU2RDdFQzYwNTk3M0NGMjkyOEQ5MDczRkI1RjM1OTMiLCJzdWIiOiIxIiwiYXV0aF90aW1lIjoxNzYyMTc1OTEwLCJpZHAiOiJsb2NhbCIsIm5hbWUiOiJtYXJpYXBwcyIsIkVtYWlsIjoiNEEwMDAzRkExNzY1NzYyOEB4eHh4LmNvbSIsIkxvZ2luTmFtZSI6Im1hcmlhcHBzIiwiVXNlcklkIjoiMSIsIkRlZmF1bHRDb21wYW55TmFtZSI6IiIsIkRpc3BsYXlOYW1lIjoibWFyaWFwcHMiLCJVc2VyVHlwZSI6IkRiIiwicmFuayI6IiIsImVudmlyb25tZW50VHlwZSI6IlZlc3NlbCJ9.iwhd5dcMX_JYOpHwakQwDOHEKsCFBImZGVWcVpl6m4-6jKnPq3zNnYqlgtpsJYEXe5E0NHGPaboPnYX-zWe_NQed4JFIxIYFn-Xia6UKuBQmmhLLOf_VmzvX67z5Cqe3_y3Ad11bbIxO-ACcWF9H8BPi9_EdFlgOH8oVHRdFDhVhSYS5IzTTetkGRMnOldvCxf1y2GvyZNsqDZNhaqz-_c-7DAPrmxBuJYYxb80Poicrsr_3qngcw__w4B_Xjks0PGtlFk-uk_3CaQEOur13BdBizgUHhAsTyrjsD_vb6iYxR4JXIFARNh4plKMYHBZlsIoFMUZPwzNu15mP6KizLw";

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

