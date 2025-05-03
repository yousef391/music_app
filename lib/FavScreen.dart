import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:tp_mobile/songDetails.dart';

import 'package:cached_network_image/cached_network_image.dart';

import 'data.dart';

class Favscreen extends StatefulWidget {
  const Favscreen({super.key});

  @override
  State<Favscreen> createState() => _FavscreenState();
}

class _FavscreenState extends State<Favscreen> with SingleTickerProviderStateMixin {
  List<Song> favoriteSongs = [];
  Song? selectedSong;
  bool isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Setup animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    getFavorites();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> getFavorites() async {
    setState(() {
      isLoading = true;
    });
    
    final favorites = await DatabaseHelper.instance.getFavorites();
    
    setState(() {
      favoriteSongs = favorites;
      isLoading = false;
    });
    
    _animationController.forward();
  }

  Future<void> _removeFavorite(Song song) async {
    // Show confirmation dialog
    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove from favorites?'),
        content: Text('Are you sure you want to remove "${song.title}" from your favorites?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    ) ?? false;
    
    if (confirm) {
      await DatabaseHelper.instance.deleteFavorite(song.id);
      
      // Show snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${song.title} removed from favorites'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(10),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () async {
                await DatabaseHelper.instance.insertFavorite(song);
                getFavorites();
              },
            ),
          ),
        );
      }
      
      setState(() {
        favoriteSongs.removeWhere((s) => s.id == song.id);
        if (selectedSong?.id == song.id) {
          selectedSong = favoriteSongs.isNotEmpty ? favoriteSongs.first : null;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "My Favorites",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: getFavorites,
            tooltip: 'Refresh favorites',
          ),
        ],
      ),
      body: isLoading 
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : favoriteSongs.isEmpty
          ? Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.favorite_border,
                      size: 80,
                      color: colorScheme.primary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No favorites yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Songs you mark as favorite will appear here',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : OrientationBuilder(
              builder: (context, orientation) {
                if (orientation == Orientation.portrait) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: SongsList(
                      songs: favoriteSongs,
                      onSongSelected: (song) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SongDetailScreen(song: song),
                          ),
                        );
                      },
                      deleteSong: (song) {
                        _removeFavorite(song);
                      },
                    ),
                  );
                } else {
                  // Initialize selectedSong if it's null and we have songs
                  if (selectedSong == null && favoriteSongs.isNotEmpty) {
                    selectedSong = favoriteSongs.first;
                  }
                  
                  return Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: SongsList(
                            songs: favoriteSongs,
                            onSongSelected: (song) {
                              setState(() {
                                selectedSong = song;
                              });
                            },
                            selectedSong: selectedSong,
                            deleteSong: (song) {
                              _removeFavorite(song);
                            },
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(30),
                              bottomLeft: Radius.circular(30),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(-5, 0),
                              ),
                            ],
                          ),
                          child: selectedSong != null
                            ? FadeTransition(
                                opacity: _fadeAnimation,
                                child: SongDetailView(song: selectedSong!),
                              )
                            : const Center(
                                child: Text(
                                  'Select a song',
                                  style: TextStyle(fontSize: 18, color: Colors.grey),
                                ),
                              ),
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
    );
  }
}

class SongDetailView extends StatelessWidget {
  final Song song;
  
  const SongDetailView({super.key, required this.song});
  
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Album art
          Center(
            child: Hero(
              tag: 'song_image_${song.id}',
              child: Container(
                width: 200,
                height: 200,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  image: DecorationImage(
                    image: AssetImage("assets/images/img.jpg"),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          
          // Song title
          Text(
            song.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          // Artist name
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            child: Text(
              song.artist ?? 'Unknown Artist',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          
          // Description heading
          const Text(
            'Description:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          
          // Description text
          Text(
            song.description,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Play button
          Center(
            child: FilledButton.icon(
              onPressed: () {
                // Navigate to music player with this song
                // You can implement this navigation
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play Now', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class SongsList extends StatelessWidget {
  final List<Song> songs;
  final Function(Song) onSongSelected;
  final Function(Song) deleteSong;
  final Song? selectedSong;

  const SongsList({
    super.key,
    required this.songs,
    required this.onSongSelected,
    this.selectedSong,
    required this.deleteSong,
  });

  @override
  Widget build(BuildContext context) {
    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: Dismissible(
                  key: Key('song_${song.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.red,
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                    ),
                  ),
                  confirmDismiss: (direction) async {
                    deleteSong(song);
                    return false; // We'll handle the removal in the deleteSong function
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    color: selectedSong?.id == song.id
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    child: InkWell(
                      onTap: () => onSongSelected(song),
                      onLongPress: () => deleteSong(song),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Song thumbnail
                            Hero(
                              tag: 'song_image_${song.id}',
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                  image: DecorationImage(
                                    image: AssetImage("assets/images/img.jpg"),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            
                            // Song info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    song.title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    song.artist ?? 'Unknown Artist',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    song.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Play button
                            IconButton(
                              icon: const Icon(Icons.play_circle_filled),
                              color: Theme.of(context).colorScheme.primary,
                              iconSize: 36,
                              onPressed: () => onSongSelected(song),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}