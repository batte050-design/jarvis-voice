import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceService {
  /// JARVIS shim base URL. This server speaks in the jarvis voice (Fish Audio)
  /// and hosts the brain. Replace with the deployed host at build time
  /// (localhost is for local development only).
  static const String shimBase = 'http://127.0.0.1:8140';

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts(); // fallback when shim unreachable
  final AudioPlayer _player = AudioPlayer();
  bool _isInitialized = false;
  bool _isListening = false;

  bool get isListening => _isListening;

  Future<void> init() async {
    if (_isInitialized) return;

    _isInitialized = await _speech.initialize(
      onError: (error) {
        _isListening = false;
      },
    );

    // Fallback TTS (used only if the shim is unreachable)
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  /// Start listening for speech. Returns transcribed text via callback.
  Future<void> startListening({
    required Function(String) onResult,
    required Function() onDone,
  }) async {
    if (!_isInitialized) await init();
    if (!_isInitialized) return;

    _isListening = true;

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        if (result.finalResult) {
          _isListening = false;
          onResult(result.recognizedWords);
          onDone();
        }
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
        partialResults: false,
      ),
    );
  }

  /// Stop listening
  Future<void> stopListening() async {
    _isListening = false;
    await _speech.stop();
  }

  /// Speak text aloud in the jarvis voice (Fish Audio via the shim).
  /// Falls back to the on-device TTS if the shim is unreachable.
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    try {
      final resp = await http
          .post(
            Uri.parse('$shimBase/v1/audio/speech'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'input': text}),
          )
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        await _player.stop();
        await _player.play(BytesSource(resp.bodyBytes));
        return;
      }
      await _tts.speak(text);
    } catch (_) {
      await _tts.speak(text);
    }
  }

  /// Stop speaking
  Future<void> stopSpeaking() async {
    await _player.stop();
    await _tts.stop();
  }

  void dispose() {
    _speech.stop();
    _tts.stop();
    _player.dispose();
  }
}
