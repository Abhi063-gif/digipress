import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final Connectivity _connectivity = Connectivity();
  final _controller = StreamController<ConnectivityResult>.broadcast();

  Stream<ConnectivityResult> get onConnectivityChanged => _controller.stream;

  Future<void> init() async {
    final result = await _connectivity.checkConnectivity();
    _controller.add(result.first); // connectivity_plus returns a list now
    
    _connectivity.onConnectivityChanged.listen((results) {
      if (results.isNotEmpty) {
        _controller.add(results.first);
      }
    });
  }

  Future<bool> get isConnected async {
    final result = await _connectivity.checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }
}
