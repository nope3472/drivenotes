import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

final connectivityProvider = StateNotifierProvider<ConnectivityNotifier, bool>(
  (ref) => ConnectivityNotifier(),
);

class ConnectivityNotifier extends StateNotifier<bool> {
  ConnectivityNotifier() : super(false) {
    _init();
  }

  StreamSubscription<ConnectivityResult>? _subscription;

  void _init() {
    _checkConnectivity();
    _subscription = Connectivity().onConnectivityChanged.listen((result) {
      state = result == ConnectivityResult.none;
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    state = result == ConnectivityResult.none;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
