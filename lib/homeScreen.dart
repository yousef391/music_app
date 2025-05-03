import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:tp_mobile/FavScreen.dart';
import 'package:tp_mobile/localMusicService.dart';

import 'audioService.dart';
import 'data.dart';
import 'main.dart';

class MusicPlayer extends StatefulWidget {
  const MusicPlayer({super.key});

  @override
  State<MusicPlayer> createState() => _MusicPlayerState();
}

class _MusicPlayerState extends State<MusicPlayer>
    with RouteAware, WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final AudioService _audioService = AudioService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Animation controller for rotating album art
  late AnimationController _animationController;
  
  List<Song> allSongs = [];
  Song? selectedSong;
  int currentSongIndex = 0;
  late Timer _timer;
  bool isExpanded = true;
  bool isPaused = true;
  bool isFavorite = false;
  bool screenoff = false;
  
  // Track progress
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  
  // For wave effect
  final List<double> _waveHeights = List.generate(30, (_) => 0.0);
  Timer? _waveTimer;
  
  // Shake detection variables
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  DateTime? _lastShakeTime;
  final double _shakeThreshold = 13.0; // Adjust sensitivity as needed
  final int _cooldownTime = 1000; // Cooldown in milliseconds
final List<Song> dummySongs = [
  Song(
    artist: 'Queen',
    id: '1',
    title: 'Bohemian Rhapsody',
    description: 'A six-minute suite by the British rock band Queen, written by Freddie Mercury. It\'s a rock opera song and has no chorus but consists of several sections: an intro, a ballad segment, an operatic passage, a hard rock part and a reflective coda.',
    audioPath: 'audio/test1.mp3',
    imagePath: 'assets/images/img.jpg',
  ),
  Song(
    artist: 'Led Zeppelin',
    id: '2',
    title: 'Stairway to Heaven',
    description: 'A song by the English rock band Led Zeppelin, released in 1971. It was composed by guitarist Jimmy Page and vocalist Robert Plant. It\'s often referred to as one of the greatest rock songs of all time.',
    audioPath: 'audio/test1.mp3',
    imagePath: 'assets/images/img.jpg',
  ),

];
  @override
  void initState() {
    super.initState();
    
    // Set up animation controller for rotating album art
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    
    WidgetsBinding.instance.addObserver(this);
    _loadSongs();
    
    // Listen to audio position changes
    _audioPlayer.onPositionChanged.listen((p) {
      setState(() => _position = p);
    });
    
    _audioPlayer.onDurationChanged.listen((d) {
      setState(() => _duration = d);
    });
    
    // Set up wave animation
    _startWaveAnimation();
    
    // Initialize shake detection
    _initShakeDetection();
  }
  
  void _initShakeDetection() {
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      // Calculate acceleration magnitude
      double acceleration = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      
      // Get current time
      DateTime now = DateTime.now();
      
      // Check if acceleration exceeds threshold and cooldown period has passed
      if (acceleration > _shakeThreshold) {
        if (_lastShakeTime == null || now.difference(_lastShakeTime!).inMilliseconds > _cooldownTime) {
          _lastShakeTime = now;
          
          // Toggle play/pause
          if (isPaused) {
            _playMusic();
          } else {
            _pauseMusic();
          }
          
          // Optional: Give haptic feedback
          HapticFeedback.mediumImpact();
        }
      }
    });
  }
  
  void _startWaveAnimation() {
    _waveTimer?.cancel();
    _waveTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!isPaused) {
        setState(() {
          for (int i = 0; i < _waveHeights.length; i++) {
            _waveHeights[i] = (isPaused ? 0.2 : (0.1 + 0.8 * (i % 3 == 0 ? 0.8 : i % 2 == 0 ? 0.5 : 0.3) * (DateTime.now().millisecondsSinceEpoch % 1000) / 1000));
          }
        });
      }
    });
  }

  Future<void> _loadSongs() async {
    // Load dummy songs immediately
    setState(() {
      allSongs = dummySongs;
      if (allSongs.isNotEmpty) {
        selectedSong = allSongs[0];
        _checkIfFavorite();
      }
    });

    // Try to load local songs if permission is granted
    final hasPermission = await LocalMusicService.requestStoragePermission();
    if (hasPermission) {
      final localSongs = await LocalMusicService.getLocalSongs();
      setState(() {
        allSongs = [...dummySongs, ...localSongs];
        if (selectedSong == null && allSongs.isNotEmpty) {
          selectedSong = allSongs[0];
          _checkIfFavorite();
        }
      });
    }
  }

  Future<void> _checkIfFavorite() async {
    if (selectedSong != null) {
      final isFav = await DatabaseHelper.instance.isFavorite(selectedSong!.id);
      setState(() {
        isFavorite = isFav;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _waveTimer?.cancel();
    _accelerometerSubscription?.cancel(); // Cancel accelerometer subscription
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  Future<void> _playMusic() async {
    if (selectedSong?.audioPath != null) {
      if (File(selectedSong!.audioPath!).existsSync()) {
        await _audioPlayer.play(DeviceFileSource(selectedSong!.audioPath!));
      } else {
        // If file doesn't exist, play the test audio file
        await _audioPlayer.play(AssetSource('audio/test1.mp3'));
      }
    } else {
      // If no audio path is specified, play the test audio file
      await _audioPlayer.play(AssetSource('audio/test1.mp3'));
    }
    _animationController.repeat();
    setState(() {
      isPaused = false;
    });
  }

  Future<void> _pauseMusic() async {
    await _audioPlayer.pause();
    _animationController.stop();
    setState(() {
      isPaused = true;
    });
  }
  
  void _nextSong() {
    if (allSongs.isEmpty) return;
    
    setState(() {
      currentSongIndex = (currentSongIndex + 1) % allSongs.length;
      selectedSong = allSongs[currentSongIndex];
      _checkIfFavorite();
    });
    
    // Stop current song and play next
    _audioPlayer.stop();
    Future.delayed(const Duration(milliseconds: 300), _playMusic);
  }
  
  void _previousSong() {
    if (allSongs.isEmpty) return;
    
    setState(() {
      currentSongIndex = (currentSongIndex - 1 + allSongs.length) % allSongs.length;
      selectedSong = allSongs[currentSongIndex];
      _checkIfFavorite();
    });
    
    // Stop current song and play previous
    _audioPlayer.stop();
    Future.delayed(const Duration(milliseconds: 300), _playMusic);
  }

  @override
  void didPushNext() {
    setState(() {
      screenoff = false;
    });
    _pauseMusic();
  }

  @override
  void didPopNext() {
    if (!isPaused) {
      setState(() {
        screenoff = true;
      });
      _playMusic();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pauseMusic();
    } else if (state == AppLifecycleState.resumed && !isPaused) {
      if (screenoff) {
        _playMusic();
      }
    }
  }

  Future<void> addFavorite() async {
    if (selectedSong != null) {
      setState(() {
        isFavorite = !isFavorite;
      });

      if (isFavorite) {
        await DatabaseHelper.instance.insertFavorite(selectedSong!);
        _showSnackBar('Added to favorites');
      } else {
        await DatabaseHelper.instance.deleteFavorite(selectedSong!.id);
        _showSnackBar('Removed from favorites');
      }
    }
  }
  
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
        duration: const Duration(seconds: 1),
      ),
    );
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background blur effect with album art
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/img.jpg"),
                fit: BoxFit.cover,
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),
          ),
          
          // Main content
          SafeArea(
            child: Column(
              children: [
                // App bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 30),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        "NOW PLAYING",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert, color: Colors.white, size: 26),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Album art with rotation animation
                Hero(
                  tag: "album_art",
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: isPaused ? 0 : _animationController.value * 6.28,
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.75,
                          height: MediaQuery.of(context).size.width * 0.75,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.375),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.purple.withOpacity(0.3),
                                blurRadius: 30,
                                spreadRadius:20 ,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.375),
                            child: Image.asset(
                              "assets/images/img.jpg",
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                const Spacer(),
                
                // Song info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedSong?.title ?? 'Unknown Song',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                selectedSong?.artist ?? 'Unknown Artist',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(
                              isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: isFavorite ? Colors.pink : Colors.white,
                              size: 28,
                            ),
                            onPressed: addFavorite,
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Progress bar
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                          activeTrackColor: Colors.purple,
                          inactiveTrackColor: Colors.grey.withOpacity(0.3),
                          thumbColor: Colors.white,
                          overlayColor: Colors.purple.withOpacity(0.3),
                        ),
                        child: Slider(
                          min: 0,
                          max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 100,
                          value: _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 100),
                          onChanged: (value) {
                            _audioPlayer.seek(Duration(seconds: value.toInt()));
                          },
                        ),
                      ),
                      
                      // Time indicators
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(_position),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _formatDuration(_duration),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Audio wave visualization
                      SizedBox(
                        height: 40,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _waveHeights.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 4,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              height: isPaused ? 5 : 5 + _waveHeights[index] * 35,
                              decoration: BoxDecoration(
                                color: isPaused 
                                    ? Colors.grey.withOpacity(0.5)
                                    : HSLColor.fromAHSL(
                                        1.0,
                                        260 + (index * 3), // Hue
                                        0.8, // Saturation
                                        0.5, // Lightness
                                      ).toColor(),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Player controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.shuffle, color: Colors.white, size: 24),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_previous, color: Colors.white, size: 40),
                            onPressed: _previousSong,
                          ),
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Colors.purple.shade300, Colors.purple.shade700],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.purple.withOpacity(0.3),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: Icon(
                                isPaused ? Icons.play_arrow : Icons.pause,
                                color: Colors.white,
                                size: 40,
                              ),
                              onPressed: isPaused ? _playMusic : _pauseMusic,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next, color: Colors.white, size: 40),
                            onPressed: _nextSong,
                          ),
                          IconButton(
                            icon: const Icon(Icons.repeat, color: Colors.white, size: 24),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}