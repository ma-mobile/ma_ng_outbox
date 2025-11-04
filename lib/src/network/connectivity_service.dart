import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity connectivity = Connectivity();

  Stream<bool> get onNetworkChange {
    return connectivity.onConnectivityChanged
        .map((result) => !(result.contains(ConnectivityResult.none)))
        .distinct();
  }

  Future<bool> get isConnected async {
    final result = await connectivity.checkConnectivity();
    return !(result.contains(ConnectivityResult.none));
  }
}
