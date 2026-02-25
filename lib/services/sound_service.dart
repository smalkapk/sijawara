import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Service untuk memutar efek suara pada animasi poin.
///
/// Taruh file MP3 di folder `lib/assets/sounds/` lalu atur path-nya di sini:
/// ─────────────────────────────────────────────────────────────────────
class SoundService {
  // ╔═══════════════════════════════════════════════════════════╗
  // ║  GANTI NAMA FILE MP3 DI SINI SESUAI FILE YANG KAMU TARUH ║
  // ╚═══════════════════════════════════════════════════════════╝

  /// Suara saat badge poin shalat muncul (+1 / +2)
  static const String pointAppearSound = 'lib/assets/sounds/point_appear.mp3';

  /// Suara saat badge bonus muncul (Bonus 5/5, Bangun Pagi, Kebaikan, Combo)
  static const String bonusAppearSound = 'lib/assets/sounds/bonus_appear.mp3';

  /// Suara saat badge terbang / meluncur ke header
  static const String flySound = 'lib/assets/sounds/fly_whoosh.mp3';

  // ─────────────────────────────────────────────────────────────

  static AudioPlayer? _pointPlayer;
  static AudioPlayer? _bonusPlayer;
  static AudioPlayer? _flyPlayer;
  static bool _initialized = false;

  static Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;

    _pointPlayer = AudioPlayer();
    _bonusPlayer = AudioPlayer();
    _flyPlayer = AudioPlayer();
  }

  /// Suara saat badge poin shalat muncul (ding!)
  static Future<void> playPointAppear() async {
    await _init();
    try {
      await _pointPlayer?.stop();
      await _pointPlayer?.play(AssetSource(pointAppearSound));
    } catch (e) {
      debugPrint('Sound error (pointAppear): $e');
    }
  }

  /// Suara saat badge bonus muncul (achievement!)
  static Future<void> playBonusAppear() async {
    await _init();
    try {
      await _bonusPlayer?.stop();
      await _bonusPlayer?.play(AssetSource(bonusAppearSound));
    } catch (e) {
      debugPrint('Sound error (bonusAppear): $e');
    }
  }

  /// Suara saat badge terbang ke header (whoosh)
  static Future<void> playFly() async {
    await _init();
    try {
      await _flyPlayer?.stop();
      await _flyPlayer?.play(AssetSource(flySound));
    } catch (e) {
      debugPrint('Sound error (fly): $e');
    }
  }

  /// Cleanup
  static void dispose() {
    _pointPlayer?.dispose();
    _bonusPlayer?.dispose();
    _flyPlayer?.dispose();
    _pointPlayer = null;
    _bonusPlayer = null;
    _flyPlayer = null;
    _initialized = false;
  }
}
