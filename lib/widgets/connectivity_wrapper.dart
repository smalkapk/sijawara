import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';
import '../theme.dart';

/// Widget pembungkus yang memantau koneksi internet di seluruh aplikasi.
///
/// Saat internet putus:
///  1. Muncul bottom sheet sekali ("Anda tidak terkoneksi internet").
///  2. Snackbar persisten di bawah layar dengan ikon connection-off.
///
/// Saat internet kembali, snackbar hilang otomatis.
class ConnectivityWrapper extends StatefulWidget {
  final Widget child;

  const ConnectivityWrapper({super.key, required this.child});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  bool _wasConnected = true;
  bool _sheetShown = false;

  @override
  void initState() {
    super.initState();
    ConnectivityService.instance.isConnected.addListener(_onConnectivityChanged);
  }

  @override
  void dispose() {
    ConnectivityService.instance.isConnected.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  void _onConnectivityChanged() {
    final connected = ConnectivityService.instance.isConnected.value;

    if (!connected && _wasConnected) {
      // Internet baru saja putus → tampilkan bottom sheet
      _wasConnected = false;
      _sheetShown = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showNoInternetSheet();
      });
    } else if (connected && !_wasConnected) {
      // Internet kembali
      _wasConnected = true;
      _sheetShown = false;
      if (mounted) setState(() {});
    }

    if (mounted) setState(() {});
  }

  void _showNoInternetSheet() {
    if (_sheetShown) return;
    _sheetShown = true;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) => const _NoInternetSheet(),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ─────────────────────────────────────────────────────────────
//  Bottom Sheet: "Anda tidak terkoneksi internet"
// ─────────────────────────────────────────────────────────────
class _NoInternetSheet extends StatelessWidget {
  const _NoInternetSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.grey200,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 24),
          // Icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              color: Color(0xFFDC2626),
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Anda tidak terkoneksi internet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Data Anda akan kami simpan dalam aplikasi sampai terdeteksi internet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppTheme.grey600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: AppTheme.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'Mengerti',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Persistent Snackbar: banner offline di bawah layar
// ─────────────────────────────────────────────────────────────
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.signal_wifi_connected_no_internet_4_rounded,
            color: Color(0xFFFCA5A5),
            size: 22,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Aplikasi tidak terkoneksi internet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
