import 'package:flutter/services.dart';
import 'data.dart';

class AudioService {
  static const MethodChannel _channel = MethodChannel('com.example.tp_mobile/audio');

  Function(bool)? onPlaybackStateChanged;
  Song? currentSong;

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

  Future<void> playAudio(Song song) async {
    try {
      currentSong = song;
      await _channel.invokeMethod('playAudio', {
        'title': song.title,
        'artist': song.artist,
        'imagePath': song.imagePath,
        'isPlaying': true,
      });
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
      if (currentSong != null) {
        await _channel.invokeMethod('updateNotification', {
          'title': currentSong!.title,
          'artist': currentSong!.artist,
          'imagePath': currentSong!.imagePath,
          'isPlaying': false,
        });
      }
    } on PlatformException catch (e) {
      print('Error pausing audio: ${e.message}');
    }
  }

  Future<void> updateNotification(Song song, bool isPlaying) async {
    try {
      await _channel.invokeMethod('updateNotification', {
        'title': song.title,
        'artist': song.artist,
        'imagePath': song.imagePath,
        'isPlaying': isPlaying,
      });
    } on PlatformException catch (e) {
      print('Error updating notification: ${e.message}');
    }
  }

  void dispose() {
    // Clean up resources
    _channel.invokeMethod('unregisterBroadcastReceiver');
  }
}