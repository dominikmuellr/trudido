import 'dart:async';
import 'package:flutter/material.dart';

void main() {
  runApp(const AutoSaveDemo());
}

class AutoSaveDemo extends StatelessWidget {
  const AutoSaveDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auto-Save with Debouncing Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const NoteEditorScreen(),
    );
  }
}

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  // TextEditingController to manage the content of the TextField
  final TextEditingController _textController = TextEditingController();
  
  // Timer for debouncing mechanism
  Timer? _debounceTimer;
  
  // Status tracking for UI feedback
  String _saveStatus = '';
  bool _isTyping = false;
  
  // Debounce duration - saves after user stops typing for this duration
  static const Duration _debounceDuration = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    
    // Listen to changes in the TextField
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    // Clean up resources
    _debounceTimer?.cancel();
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    super.dispose();
  }

  /// Called whenever the text in the TextField changes
  /// Implements the debouncing logic to prevent excessive save operations
  void _onTextChanged() {
    // Cancel any existing timer to reset the debounce period
    _debounceTimer?.cancel();
    
    // Update UI to show that user is typing
    if (!_isTyping) {
      setState(() {
        _isTyping = true;
        _saveStatus = 'Typing...';
      });
    }
    
    // Start a new timer for the debounce period
    _debounceTimer = Timer(_debounceDuration, () {
      // This callback is executed only after the user stops typing
      // for the specified duration
      _performAutoSave();
    });
  }

  /// Performs the actual auto-save operation
  /// This is called only after the debounce timer completes
  void _performAutoSave() {
    if (_textController.text.isNotEmpty) {
      setState(() {
        _saveStatus = 'Saving...';
        _isTyping = false;
      });
      
      // Call the mock save function
      _saveNote();
      
      // Update status after save
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _saveStatus = 'Saved automatically';
          });
          
          // Clear the status message after a short delay
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _saveStatus = '';
              });
            }
          });
        }
      });
    } else {
      setState(() {
        _isTyping = false;
        _saveStatus = '';
      });
    }
  }

  /// Mock save function that simulates saving the note to a data source
  /// In a real app, this would involve database operations or API calls
  void _saveNote() {
    final content = _textController.text;
    final timestamp = DateTime.now().toIso8601String();
    
    // Simulate the save operation with console output
    debugPrint('=== AUTO-SAVE TRIGGERED ===');
    debugPrint('Timestamp: $timestamp');
    debugPrint('Content length: ${content.length} characters');
    debugPrint('Content preview: ${content.length > 50 ? '${content.substring(0, 50)}...' : content}');
    debugPrint('Note saved successfully!');
    debugPrint('============================');
    
    // In a real implementation, you might:
    // - Save to local database (SQLite, Hive, etc.)
    // - Send to remote server via API
    // - Update shared preferences
    // - Trigger cloud sync
  }

  /// Manual save function for explicit user-triggered saves
  void _manualSave() {
    _debounceTimer?.cancel();
    setState(() {
      _saveStatus = 'Saving...';
    });
    
    _saveNote();
    
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _saveStatus = 'Saved manually';
        });
        
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _saveStatus = '';
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto-Save Notes Editor'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Manual save button for comparison
          IconButton(
            onPressed: _manualSave,
            icon: const Icon(Icons.save),
            tooltip: 'Manual Save',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: _getStatusColor(),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_saveStatus.isNotEmpty) ...[
                    Icon(
                      _getStatusIcon(),
                      size: 16.0,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8.0),
                  ],
                  Text(
                    _saveStatus.isEmpty ? 'Ready' : _saveStatus,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),
            
            // Information card explaining the debouncing feature
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Auto-Save with Debouncing',
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      'This demo shows how debouncing prevents excessive save operations. '
                      'The note will be automatically saved ${_debounceDuration.inSeconds} seconds after you stop typing.',
                      style: TextStyle(
                        fontSize: 14.0,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha((255 * 0.7).round()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            
            // Main text editor
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Start typing your note here...\n\nThe content will be automatically saved after you stop typing for 2 seconds.',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(16.0),
                ),
                style: const TextStyle(
                  fontSize: 16.0,
                  height: 1.5,
                ),
              ),
            ),
            
            const SizedBox(height: 16.0),
            
            // Debug information
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Debug Info:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.0,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    'Characters: ${_textController.text.length}',
                    style: const TextStyle(fontSize: 12.0),
                  ),
                  Text(
                    'Debounce Timer: ${_debounceTimer?.isActive == true ? 'Active' : 'Inactive'}',
                    style: const TextStyle(fontSize: 12.0),
                  ),
                  const Text(
                    'Check console for save logs',
                    style: TextStyle(
                      fontSize: 12.0,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns appropriate color based on current save status
  Color _getStatusColor() {
    switch (_saveStatus) {
      case 'Typing...':
        return Colors.blue;
      case 'Saving...':
        return Colors.orange;
      case 'Saved automatically':
      case 'Saved manually':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  /// Returns appropriate icon based on current save status
  IconData _getStatusIcon() {
    switch (_saveStatus) {
      case 'Typing...':
        return Icons.edit;
      case 'Saving...':
        return Icons.cloud_upload;
      case 'Saved automatically':
      case 'Saved manually':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }
}
