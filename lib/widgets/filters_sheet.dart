import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/filter_providers.dart';

/// Shows the full, draggable filters sheet used by the overflow menu.
///
/// This is extracted so the greeting header and the overflow menu open the
/// exact same sheet.
Future<void> showFiltersSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        expand: true,
        initialChildSize: 0.95,
        minChildSize: 0.25,
        maxChildSize: 0.95,
        builder: (context, controller) {
          return Consumer(
            builder: (ctx, innerRef, _) {
              final p = innerRef.watch(selectedPriorityProvider);
              final s = innerRef.watch(showCompletedProvider);
              final sort = innerRef.watch(sortByProvider);

              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 12,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: controller,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'Filters',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Divider(),

                          const Padding(
                            padding: EdgeInsets.only(top: 8.0, bottom: 4.0),
                            child: Text(
                              'Priority',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          RadioListTile<String>(
                            title: const Text('All Priorities'),
                            value: 'all',
                            groupValue: p,
                            onChanged: (v) =>
                                innerRef
                                        .read(selectedPriorityProvider.notifier)
                                        .state =
                                    v ?? 'all',
                          ),
                          RadioListTile<String>(
                            title: const Text('High Priority'),
                            value: 'high',
                            groupValue: p,
                            onChanged: (v) =>
                                innerRef
                                        .read(selectedPriorityProvider.notifier)
                                        .state =
                                    v ?? 'high',
                          ),
                          RadioListTile<String>(
                            title: const Text('Medium Priority'),
                            value: 'medium',
                            groupValue: p,
                            onChanged: (v) =>
                                innerRef
                                        .read(selectedPriorityProvider.notifier)
                                        .state =
                                    v ?? 'medium',
                          ),
                          RadioListTile<String>(
                            title: const Text('Low Priority'),
                            value: 'low',
                            groupValue: p,
                            onChanged: (v) =>
                                innerRef
                                        .read(selectedPriorityProvider.notifier)
                                        .state =
                                    v ?? 'low',
                          ),

                          const SizedBox(height: 8),

                          SwitchListTile(
                            title: const Text('Show Completed'),
                            value: s,
                            onChanged: (value) =>
                                innerRef
                                        .read(showCompletedProvider.notifier)
                                        .state =
                                    value,
                          ),

                          const SizedBox(height: 8),

                          const Padding(
                            padding: EdgeInsets.only(top: 8.0, bottom: 4.0),
                            child: Text(
                              'Sort by',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          RadioListTile<String>(
                            title: const Text('Default'),
                            value: 'default',
                            groupValue: sort,
                            onChanged: (v) =>
                                innerRef.read(sortByProvider.notifier).state =
                                    v ?? 'default',
                          ),
                          RadioListTile<String>(
                            title: const Text('Date Created'),
                            value: 'date_created',
                            groupValue: sort,
                            onChanged: (v) =>
                                innerRef.read(sortByProvider.notifier).state =
                                    v ?? 'date_created',
                          ),
                          RadioListTile<String>(
                            title: const Text('Due Date'),
                            value: 'date_due',
                            groupValue: sort,
                            onChanged: (v) =>
                                innerRef.read(sortByProvider.notifier).state =
                                    v ?? 'date_due',
                          ),
                          RadioListTile<String>(
                            title: const Text('Priority'),
                            value: 'priority',
                            groupValue: sort,
                            onChanged: (v) =>
                                innerRef.read(sortByProvider.notifier).state =
                                    v ?? 'priority',
                          ),
                          RadioListTile<String>(
                            title: const Text('Alphabetical'),
                            value: 'alphabetical',
                            groupValue: sort,
                            onChanged: (v) =>
                                innerRef.read(sortByProvider.notifier).state =
                                    v ?? 'alphabetical',
                          ),

                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('Close'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  );
}
