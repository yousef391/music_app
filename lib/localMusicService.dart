import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'data.dart';

class LocalMusicService {
  static Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      // Request both storage and media permissions
      final storageStatus = await Permission.storage.request();
      final mediaStatus = await Permission.audio.request();
      return storageStatus.isGranted || mediaStatus.isGranted;
    }
    return true;
  }

  static Future<List<Song>> getLocalSongs() async {
    List<Song> localSongs = [];
    
    if (Platform.isAndroid) {
      final storageStatus = await Permission.storage.status;
      final mediaStatus = await Permission.audio.status;
      
      if (!storageStatus.isGranted && !mediaStatus.isGranted) {
        debugPrint('Storage and media permissions not granted');
        return localSongs;
      }

      try {
        // Try different possible music directory paths
        final possiblePaths = [
          '/storage/emulated/0/Music',
          '/storage/emulated/0/Download',
          '/storage/emulated/0/DCIM',
          '/storage/emulated/0/Android/media',
          '/storage/emulated/0/Android/data',
          '/storage/emulated/0/Download/Music',
          '/storage/emulated/0/Download/music',
          '/storage/emulated/0/Download/Songs',
          '/storage/emulated/0/Download/songs',
          '/sdcard/Music',  // Common emulator path
          '/sdcard/Download',  // Common emulator path
        ];

        for (var path in possiblePaths) {
          final directory = Directory(path);
          if (await directory.exists()) {
            debugPrint('Scanning directory: $path');
            try {
              final files = await directory.list(recursive: true).toList();
              debugPrint('Found ${files.length} files in $path');
              
              for (var file in files) {
                if (file.path.toLowerCase().endsWith('.mp3')) {
                  debugPrint('Found MP3: ${file.path}');
                  final fileName = file.path.split('/').last;
                  final songName = fileName.replaceAll('.mp3', '');
                  
                  localSongs.add(Song(
                    artist: 'Local Artist',
                    id: file.path.hashCode.toString(),
                    title: songName,
                    description: 'Local Song from your device',
                    audioPath: file.path,
                    imagePath: 'assets/images/img.png',
                  ));
                }
              }
            } catch (e) {
              debugPrint('Error reading directory $path: $e');
            }
          } else {
            debugPrint('Directory not found: $path');
          }
        }

        // Also try to get external storage directory
        try {
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            debugPrint('Scanning external storage directory: ${externalDir.path}');
            final files = await externalDir.list(recursive: true).toList();
            debugPrint('Found ${files.length} files in external storage');
            
            for (var file in files) {
              if (file.path.toLowerCase().endsWith('.mp3')) {
                debugPrint('Found MP3: ${file.path}');
                final fileName = file.path.split('/').last;
                final songName = fileName.replaceAll('.mp3', '');
                
                localSongs.add(Song(
                  artist: 'Local Artist',
                  id: file.path.hashCode.toString(),
                  title: songName,
                  description: 'Local Song from your device',
                  audioPath: file.path,
                  imagePath: 'assets/images/img.png',
                ));
              }
            }
          }
        } catch (e) {
          debugPrint('Error accessing external storage: $e');
        }

      } catch (e) {
        debugPrint('Error scanning local music: $e');
      }
    }
    
    debugPrint('Total local songs found: ${localSongs.length}');
    return localSongs;
  }
} 