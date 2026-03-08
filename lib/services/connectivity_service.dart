import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Singleton service yang memantau status koneksi internet secara real-time.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// [ValueNotifier] yang bisa di-listen dari mana saja.
  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(true);

  /// Apakah service sudah di-init.
  bool _initialized = false;

  /// Inisialisasi. Panggil sekali saja (dari main).
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Cek status awal
    final results = await _connectivity.checkConnectivity();
    isConnected.value = await _hasRealInternet(results);

    // Listen perubahan koneksi
    _subscription = _connectivity.onConnectivityChanged.listen((results) async {
      final connected = await _hasRealInternet(results);
      if (isConnected.value != connected) {
        isConnected.value = connected;
      }
    });
  }

  /// Cek apakah benar-benar bisa akses internet (bukan hanya Wi-Fi tanpa internet).
  Future<bool> _hasRealInternet(List<ConnectivityResult> results) async {
    if (results.contains(ConnectivityResult.none)) return false;
    // Ada network interface, cek DNS lookup untuk konfirmasi
    try {
      final result = await InternetAddress.lookup('portal-smalka.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _initialized = false;
  }
}
