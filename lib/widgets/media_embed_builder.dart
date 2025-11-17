import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';

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
        return _buildImage(filePath);
      case 'video':
        return _buildVideoPlaceholder(filePath);
      case 'voice':
        return _buildAudioPlayer(filePath);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildImage(String filePath) {
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

    return Container(
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
    );
  }

  Widget _buildVideoPlaceholder(String filePath) {
    final fileName = filePath.split('/').last;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.videocam, color: Colors.blue[700], size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Video',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  fileName,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.play_circle_outline, color: Colors.blue[700], size: 32),
        ],
      ),
    );
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
