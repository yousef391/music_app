import 'package:flutter/services.dart';

class AudioService {
  static const MethodChannel _channel = MethodChannel('com.example.tp_mobile/audio');

  Function(bool)? onPlaybackStateChanged;

  AudioService() {
    _channel.setMethodCallHandler(_handleMethodCall);

    // Register for broadcast events
    _channel.invokeMethod('registerBroadcastReceiver');
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onPlaybackStateChanged':
        final bool isPlaying = call.arguments as bool;
        if (onPlaybackStateChanged != null) {
          onPlaybackStateChanged!(isPlaying);
        }
        break;
      default:
        print('Method not implemented: ${call.method}');
    }
  }

  Future<void> playAudio() async {
    try {
      await _channel.invokeMethod('playAudio');
    } on PlatformException catch (e) {
      print('Error playing audio: ${e.message}');
    } on MissingPluginException catch (e) {
      print('Missing plugin exception: ${e.message}');
    } catch (e) {
      print('Unexpected error: $e');
    }
  }

  Future<void> pauseAudio() async {
    try {
      await _channel.invokeMethod('pauseAudio');
    } on PlatformException catch (e) {
      print('Error pausing audio: ${e.message}');
    }
  }

  void dispose() {
    // Clean up resources
    _channel.invokeMethod('unregisterBroadcastReceiver');
  }
}