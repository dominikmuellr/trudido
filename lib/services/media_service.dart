import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Service for handling media operations (photos, videos, voice recordings)
class MediaService {
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();

  /// Pick image from gallery
  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // Compress to reduce size
      );
      return image != null ? File(image.path) : null;
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
      return null;
    }
  }

  /// Take photo with camera
  Future<File?> takePhoto() async {
    // Request camera permission
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      debugPrint('Camera permission denied');
      return null;
    }

    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      return photo != null ? File(photo.path) : null;
    } catch (e) {
      debugPrint('Error taking photo: $e');
      return null;
    }
  }

  /// Pick video from gallery
  Future<File?> pickVideoFromGallery() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
      );
      return video != null ? File(video.path) : null;
    } catch (e) {
      debugPrint('Error picking video from gallery: $e');
      return null;
    }
  }

  /// Record video with camera
  Future<File?> recordVideo() async {
    // Request camera permission
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      debugPrint('Camera permission denied');
      return null;
    }

    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5), // Limit to 5 minutes
      );
      return video != null ? File(video.path) : null;
    } catch (e) {
      debugPrint('Error recording video: $e');
      return null;
    }
  }

  /// Show dialog to choose between gallery and camera for photos
  Future<File?> pickOrTakePhoto(BuildContext context) async {
    return showDialog<File?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Photo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final file = await pickImageFromGallery();
                if (context.mounted) {
                  Navigator.pop(context, file);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(context);
                final file = await takePhoto();
                if (context.mounted) {
                  Navigator.pop(context, file);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Show dialog to choose between gallery and camera for videos
  Future<File?> pickOrRecordVideo(BuildContext context) async {
    return showDialog<File?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Video'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final file = await pickVideoFromGallery();
                if (context.mounted) {
                  Navigator.pop(context, file);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Record Video'),
              onTap: () async {
                Navigator.pop(context);
                final file = await recordVideo();
                if (context.mounted) {
                  Navigator.pop(context, file);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Start recording audio
  Future<bool> startRecording() async {
    // Request microphone permission
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      debugPrint('Microphone permission denied');
      return false;
    }

    try {
      // Check if recorder has permission
      if (await _audioRecorder.hasPermission()) {
        // Get temporary directory for recording
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath = path.join(tempDir.path, 'voice_note_$timestamp.m4a');

        await _audioRecorder.start(
          const RecordConfig(
            encoder:
                AudioEncoder.aacLc, // AAC format, compatible with most devices
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: filePath,
        );
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error starting recording: $e');
      return false;
    }
  }

  /// Stop recording and return the audio file
  Future<File?> stopRecording() async {
    try {
      final filePath = await _audioRecorder.stop();
      if (filePath != null) {
        return File(filePath);
      }
      return null;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      return null;
    }
  }

  /// Check if currently recording
  Future<bool> isRecording() async {
    try {
      return await _audioRecorder.isRecording();
    } catch (e) {
      debugPrint('Error checking recording status: $e');
      return false;
    }
  }

  /// Cancel recording without saving
  Future<void> cancelRecording() async {
    try {
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }
    } catch (e) {
      debugPrint('Error canceling recording: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _audioRecorder.dispose();
  }

  /// Copy file to app's documents directory with a proper name
  Future<File> saveMediaToAppDirectory(File sourceFile, String prefix) async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(path.join(appDir.path, 'media'));
    if (!mediaDir.existsSync()) {
      mediaDir.createSync(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = path.extension(sourceFile.path);
    final fileName = '${prefix}_$timestamp$extension';
    final targetPath = path.join(mediaDir.path, fileName);

    return sourceFile.copy(targetPath);
  }
}
