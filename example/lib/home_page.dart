import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ma_ng_outbox/ma_ng_outbox.dart';
import 'package:ma_ng_outbox/objectbox.g.dart';

import 'main.dart'; // for GlobalAccessTokenHolder & objectBox

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<OutboxItem> pending = [];
  List<OutboxItem> synced = [];

  @override
  void initState() {
    super.initState();
    _loadOutbox();
  }

  Future<void> _loadOutbox() async {
    final box = objectBox.outboxBox;

    setState(() {
      pending = box.query(OutboxItem_.isSynced.equals(0))
          .order(OutboxItem_.createdAt)
          .build()
          .find();

      synced = box.query(OutboxItem_.isSynced.equals(1))
          .order(OutboxItem_.createdAt)
          .build()
          .find();
    });
  }

  Future<void> _addOutboxItem() async {
    // await objectBox.addToOutbox(
    //   operation: "POST",
    //   url: "https://jsonplaceholder.typicode.com/posts",
    //   payload: {
    //     "title": "Hello Outbox",
    //     "body": "Testing offline sync",
    //     "userId": DateTime.now().millisecondsSinceEpoch,
    //   },
    //   tableName: "posts",
    //   primaryKey: "local-${DateTime.now().millisecondsSinceEpoch}",
    // );


    await objectBox.addToOutbox(
      operation: "GET",
      url: "https://palng-qa-vsl.mariapps.com/ApiGateway/document/api/SPS/SPS_TRN_GRN/4f5c9697-2b5a-4bde-89a3-844a5fa3d478/preview",
      // payload: {
      //   "title": "Hello Outbox",
      //   "body": "Testing offline sync",
      //   "userId": DateTime.now().millisecondsSinceEpoch,
      // },
      endPoint: "posts",
      priority: Priority.medium,
      primaryKey: "local-${DateTime.now().millisecondsSinceEpoch}",
    );

    await _loadOutbox();
  }

  Future<void> _forceSync() async {
    if (GlobalAccessTokenHolder.token == null) return;

    await SyncController.runIsolateSync(
      token: GlobalAccessTokenHolder.token!,
      rootToken: ServicesBinding.rootIsolateToken!,
      objectBox: objectBox
    );

    await Future.delayed(const Duration(seconds: 2));
    await _loadOutbox();
  }

  Widget _buildCard(String title, List<OutboxItem> items, Color color) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      elevation: 2,
      child: ExpansionTile(
        title: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        children: items.map((item) {
          return ListTile(
            title: Text(item.url),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.payload != null) ...[
                  const SizedBox(height: 6),
                  Text("Payload:", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(item.payload!, style: TextStyle(color: color)),
                ],
                if (item.response != null) ...[
                  const SizedBox(height: 6),
                  Text("Response:", style: TextStyle(fontWeight: FontWeight.bold)),
                  buildResponseWidget(item.response!),
                ],
                const SizedBox(height: 10),
                Text(
                  "Created: ${DateTime.fromMillisecondsSinceEpoch(item.createdAt)}",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Offline Outbox Sync",style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.blueAccent,
      ),

      body: RefreshIndicator(
        onRefresh: _loadOutbox,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildCard("Pending Outbox Items (${pending.length})", pending, Colors.red),
              _buildCard("Synced Items (${synced.length})", synced, Colors.green),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _addOutboxItem,
                icon: const Icon(Icons.add),
                label: const Text("Add Outbox Item"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _forceSync,
                icon: const Icon(Icons.sync,color: Colors.white),
                label: const Text("Force Sync Now",style: TextStyle(color: Colors.white),),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildResponseWidget(String response) {
    final type = detectResponseType(response);

    switch (type) {
      case ResponseTypeKind.base64:
        try {
          final bytes = base64Decode(response);
          return Image.memory(bytes, height: 200, fit: BoxFit.contain);
        } catch (e) {
          return Text("Invalid Base64 data");
        }

      case ResponseTypeKind.json:
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text(response),
        );

      case ResponseTypeKind.text:
      default:
        return Text(response);
    }
  }

}

enum ResponseTypeKind { json, base64, text }

ResponseTypeKind detectResponseType(String value) {
  final s = value.trim();

  // JSON detection
  if ((s.startsWith('{') && s.endsWith('}')) ||
      (s.startsWith('[') && s.endsWith(']'))) {
    return ResponseTypeKind.json;
  }

  // Base64 detection (rough check)
  final base64Regex = RegExp(r'^[A-Za-z0-9+/=]+$');
  if (base64Regex.hasMatch(s)) return ResponseTypeKind.base64;

  return ResponseTypeKind.text;
}
