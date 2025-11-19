import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

/// Custom embed builder for rendering media (images, videos, audio) in Quill editor
class MediaEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'media';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final node = embedContext.node;
    final dataString = node.value.data as String;

    // Parse JSON string to map
    Map<String, dynamic> data;
    try {
      data = jsonDecode(dataString) as Map<String, dynamic>;
    } catch (e) {
      // If parsing fails, show error widget
      return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('Error loading media: $e'),
      );
    }

    final mediaType = data['type'] as String;
    final filePath = data['path'] as String;

    switch (mediaType) {
      case 'image':
        return _buildImage(context, filePath);
      case 'video':
        return _buildVideoPlayer(filePath);
      case 'voice':
        return _buildAudioPlayer(filePath);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildImage(BuildContext context, String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            Icon(Icons.broken_image, color: Colors.grey),
            SizedBox(width: 8),
            Text('Image not found'),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        // Open fullscreen image viewer
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => FullscreenImageViewer(imagePath: filePath),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        constraints: const BoxConstraints(
          maxWidth: double.infinity,
          maxHeight: 400, // Limit image height for better scrolling
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            file,
            fit: BoxFit.contain, // Changed from cover to contain
            errorBuilder: (context, error, stackTrace) {
              return Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[200],
                child: const Row(
                  children: [
                    Icon(Icons.broken_image, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Error loading image'),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPlayer(String filePath) {
    return VideoPlayerWidget(videoPath: filePath);
  }

  Widget _buildAudioPlayer(String filePath) {
    return AudioPlayerWidget(filePath: filePath);
  }
}

/// Simple audio player widget for voice notes
class AudioPlayerWidget extends StatefulWidget {
  final String filePath;

  const AudioPlayerWidget({super.key, required this.filePath});

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      // Set up event listeners
      _audioPlayer.onDurationChanged.listen((duration) {
        if (mounted) {
          setState(() {
            _duration = duration;
            _isLoading = false;
          });
        }
      });

      _audioPlayer.onPositionChanged.listen((position) {
        if (mounted) {
          setState(() {
            _position = position;
          });
        }
      });

      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
          });
        }
      });

      // Set the source
      await _audioPlayer.setSourceDeviceFile(widget.filePath);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _getRecordingDateTime() {
    try {
      final file = File(widget.filePath);
      if (file.existsSync()) {
        final lastModified = file.lastModifiedSync();
        final dateFormat = DateFormat('MMM d, y · h:mm a');
        return dateFormat.format(lastModified);
      }
    } catch (e) {}
    return 'Voice Recording';
  }

  @override
  Widget build(BuildContext context) {
    final recordingDateTime = _getRecordingDateTime();
    final formattedDuration = _formatDuration(_duration);
    final formattedPosition = _formatDuration(_position);

    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mic, color: primaryColor, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  recordingDateTime,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _isLoading
                  ? SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: primaryColor,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : IconButton(
                      onPressed: _togglePlayPause,
                      icon: Icon(
                        _isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        size: 40,
                        color: primaryColor,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: _duration.inMilliseconds > 0
                          ? _position.inMilliseconds / _duration.inMilliseconds
                          : 0,
                      backgroundColor: primaryColor.withOpacity(0.2),
                      color: primaryColor,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$formattedPosition / $formattedDuration',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.resume();
      }
      setState(() {
        _isPlaying = !_isPlaying;
      });
    } catch (e) {}
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

/// Fullscreen image viewer with pinch-to-zoom and swipe-to-dismiss
class FullscreenImageViewer extends StatefulWidget {
  final String imagePath;

  const FullscreenImageViewer({super.key, required this.imagePath});

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Dismissible wrapper for swipe-to-close
            Dismissible(
              key: const Key('fullscreen_image'),
              direction: DismissDirection.vertical,
              onDismissed: (direction) {
                Navigator.of(context).pop();
              },
              child: Center(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              size: 64,
                              color: Colors.white54,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Error loading image',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Video player widget with controls
class VideoPlayerWidget extends StatefulWidget {
  final String videoPath;

  const VideoPlayerWidget({super.key, required this.videoPath});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.file(File(widget.videoPath));
      await _controller.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Error loading video',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red[600], fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_controller),
              // Play/Pause overlay
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_controller.value.isPlaying) {
                        _controller.pause();
                      } else {
                        _controller.play();
                      }
                    });
                  },
                  child: Container(
                    color: Colors.transparent,
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: _controller.value.isPlaying ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _controller.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Video progress bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                    playedColor: Theme.of(context).colorScheme.primary,
                    bufferedColor: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.3),
                    backgroundColor: Colors.white.withOpacity(0.3),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
