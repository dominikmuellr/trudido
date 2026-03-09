import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../models/todo.dart';
import '../models/event.dart' as app_event;
import '../models/note.dart';
import '../providers/app_providers.dart';
import '../repositories/notes_repository.dart';
import '../repositories/note_folder_repository.dart';
import '../widgets/common/common.dart';

class BinScreen extends ConsumerStatefulWidget {
  final int initialTab;

  const BinScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<BinScreen> createState() => _BinScreenState();
}

class _BinScreenState extends ConsumerState<BinScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Todo> _deletedTasks = [];
  List<app_event.Event> _deletedEvents = [];
  List<Note> _deletedNotes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final taskRepo = ref.read(taskRepositoryProvider);
    _deletedTasks = await taskRepo.getDeletedTasks();

    final eventRepo = ref.read(eventRepositoryProvider);
    _deletedEvents = await eventRepo.getDeletedEvents();

    final notesRepo = ref.read(notesRepositoryProvider);
    final allDeletedNotes = await notesRepo.getDeletedNotes();
    final folderRepo = ref.read(noteFolderRepositoryProvider);

    final nonVaultNotes = <Note>[];
    for (final note in allDeletedNotes) {
      if (note.folderId == null) {
        nonVaultNotes.add(note);
        continue;
      }
      final folder = folderRepo.getNoteFolderById(note.folderId!);
      if (folder == null || !folder.isVault) {
        nonVaultNotes.add(note);
      }
    }
    _deletedNotes = nonVaultNotes;

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _emptyBin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Empty Bin?'),
        content: const Text(
          'All items in the bin will be permanently deleted. This cannot be undone.',
        ),
        actions: [
          ExpressiveTextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ExpressiveTextButton(
            onPressed: () => Navigator.pop(context, true),
            style: ExpressiveTextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Empty Bin'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (_tabController.index == 0) {
        await ref.read(taskRepositoryProvider).emptyBin();
      } else if (_tabController.index == 1) {
        await ref.read(eventRepositoryProvider).emptyBin();
      } else {
        await ref
            .read(notesRepositoryProvider)
            .emptyBin(false); // false = non-vault
      }
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bin'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'To-dos'),
            Tab(text: 'Events'),
            Tab(text: 'Notes'),
          ],
        ),
        actions: [
          ExpressiveIconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Empty Bin',
            onPressed: _emptyBin,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildTaskList(), _buildEventList(), _buildNoteList()],
            ),
    );
  }

  Widget _buildTaskList() {
    if (_deletedTasks.isEmpty) {
      return const Center(child: Text('No deleted tasks'));
    }
    return ListView.builder(
      itemCount: _deletedTasks.length,
      itemBuilder: (context, index) {
        final task = _deletedTasks[index];
        return ListTile(
          title: Text(
            task.text,
            style: const TextStyle(decoration: TextDecoration.lineThrough),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExpressiveIconButton(
                icon: const Icon(Icons.restore),
                onPressed: () async {
                  await ref.read(taskRepositoryProvider).restoreTask(task.id);
                  _loadData();
                  final _ = ref.refresh(tasksProvider); // Refresh main list
                },
              ),
              ExpressiveIconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                onPressed: () async {
                  await ref
                      .read(taskRepositoryProvider)
                      .permanentlyDeleteTask(task.id);
                  _loadData();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventList() {
    if (_deletedEvents.isEmpty) {
      return const Center(child: Text('No deleted events'));
    }
    return ListView.builder(
      itemCount: _deletedEvents.length,
      itemBuilder: (context, index) {
        final event = _deletedEvents[index];
        final timeText = event.isAllDay
            ? 'All day'
            : '${DateFormat('MMM d, HH:mm').format(event.startDateTime)} – ${DateFormat('HH:mm').format(event.endDateTime)}';
        return ListTile(
          leading: const Icon(Icons.event),
          title: Text(
            event.text,
            style: const TextStyle(decoration: TextDecoration.lineThrough),
          ),
          subtitle: Text(timeText),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExpressiveIconButton(
                icon: const Icon(Icons.restore),
                onPressed: () async {
                  await ref
                      .read(eventRepositoryProvider)
                      .restoreEvent(event.id);
                  _loadData();
                  final _ = ref.refresh(eventsProvider);
                },
              ),
              ExpressiveIconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                onPressed: () async {
                  await ref
                      .read(eventRepositoryProvider)
                      .permanentlyDeleteEvent(event.id);
                  _loadData();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoteList() {
    if (_deletedNotes.isEmpty) {
      return const Center(child: Text('No deleted notes'));
    }
    return ListView.builder(
      itemCount: _deletedNotes.length,
      itemBuilder: (context, index) {
        final note = _deletedNotes[index];
        return ListTile(
          title: Text(note.title),
          subtitle: Text(
            _extractPlainText(note.content),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExpressiveIconButton(
                icon: const Icon(Icons.restore),
                onPressed: () async {
                  await ref.read(notesRepositoryProvider).restoreNote(note.id);
                  _loadData();
                  final _ = ref.refresh(notesProvider); // Refresh main list
                },
              ),
              ExpressiveIconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                onPressed: () async {
                  await ref
                      .read(notesRepositoryProvider)
                      .permanentlyDeleteNote(note.id);
                  _loadData();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Extract plain text from Quill JSON content
  String _extractPlainText(String jsonContent) {
    try {
      final decoded = jsonDecode(jsonContent);
      if (decoded is List) {
        final buffer = StringBuffer();
        for (final delta in decoded) {
          if (delta is Map && delta.containsKey('insert')) {
            final insert = delta['insert'];
            if (insert is String) {
              buffer.write(insert);
            }
          }
        }
        return buffer.toString().trim().replaceAll('\n', ' ');
      }
      return jsonContent;
    } catch (e) {
      // If parsing fails, return a truncated version of the raw content
      return jsonContent.length > 50
          ? '${jsonContent.substring(0, 50)}...'
          : jsonContent;
    }
  }
}
