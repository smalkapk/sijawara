import 'package:geolocator/geolocator.dart';

/// Service untuk mengambil lokasi GPS siswa saat tracking shalat.
class LocationService {
  /// Cek & minta izin lokasi, lalu ambil posisi GPS saat ini.
  /// Mengembalikan [LocationData] berisi lat, lng, dan nama lokasi sederhana.
  /// Throw [LocationServiceException] jika gagal.
  static Future<LocationData> getCurrentLocation() async {
    // 1. Cek apakah location service aktif
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationServiceException(
        'Layanan lokasi tidak aktif. Aktifkan GPS Anda.',
      );
    }

    // 2. Cek & minta permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationServiceException(
          'Izin lokasi ditolak. Aktifkan izin lokasi di pengaturan.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationServiceException(
        'Izin lokasi ditolak permanen. Buka pengaturan untuk mengaktifkan.',
      );
    }

    // 3. Ambil posisi terkini
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );
    } catch (e) {
      throw LocationServiceException(
        'Gagal mendapatkan lokasi: ${e.toString()}',
      );
    }
  }

  /// Cek apakah sudah memiliki izin lokasi (tanpa meminta).
  static Future<bool> hasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Buka halaman settings perangkat untuk izin lokasi.
  static Future<bool> openSettings() async {
    return await Geolocator.openAppSettings();
  }
}

/// Model data lokasi
class LocationData {
  final double latitude;
  final double longitude;
  final double accuracy;

  const LocationData({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });

  @override
  String toString() =>
      'LocationData(lat: $latitude, lng: $longitude, acc: ${accuracy.toStringAsFixed(1)}m)';
}

/// Exception khusus LocationService
class LocationServiceException implements Exception {
  final String message;
  LocationServiceException(this.message);

  @override
  String toString() => message;
}
