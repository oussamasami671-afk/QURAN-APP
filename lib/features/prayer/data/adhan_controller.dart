import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

class AdhanController extends ChangeNotifier {
  AdhanController._();

  static final AdhanController instance = AdhanController._();

  static const MethodChannel _volumeKeyChannel =
      MethodChannel('quran_app/volume_keys');

  final AudioPlayer _player = AudioPlayer();

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    _volumeKeyChannel.setMethodCallHandler((call) async {
      if (call.method == 'volumeKeyPressed' && _player.playing) {
        await stop();
      }
    });

    debugPrint('ADHAN: Loading audio...');

    try {
      final duration = await _player.setAsset(
        'assets/audio/adhan_fixed.mp3',
      );

      debugPrint('ADHAN: Loaded successfully');
      debugPrint('ADHAN: Duration = $duration');

      _player.playerStateStream.listen((state) {
        _isPlaying = state.playing;
        notifyListeners();
      });

      _isInitialized = true;
    } catch (e, stackTrace) {
      debugPrint('ADHAN LOAD ERROR: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  Future<void> play() async {
    try {
      debugPrint('ADHAN: Play pressed');

      await initialize();
      await _player.seek(Duration.zero);
      await _player.play();

      debugPrint('ADHAN: Playback completed');
    } catch (e, stackTrace) {
      debugPrint('ADHAN PLAY ERROR: $e');
      debugPrint('$stackTrace');
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
      _isPlaying = false;
      notifyListeners();

      debugPrint('ADHAN: Stopped');
    } catch (e) {
      debugPrint('ADHAN STOP ERROR: $e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
