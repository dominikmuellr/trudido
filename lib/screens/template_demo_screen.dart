import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/template_provider.dart';
import '../widgets/create_folder_dialog.dart';
import '../screens/template_management_screen.dart';

/// Demo screen to showcase Phase 1 template functionality
class TemplateDemoScreen extends ConsumerWidget {
  const TemplateDemoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(templateNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('📁 Phase 1: Template System'),
        backgroundColor: Colors.green.shade50,
        foregroundColor: Colors.green.shade800,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TemplateManagementScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Success banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    '🎉 Phase 1 Complete!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Smart folder creation with template suggestions',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // What's working section
            Text(
              '✅ What\'s Working',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            _buildFeatureCard(
              context,
              '🧠 Smart Template Suggestions',
              'Type "Kitchen Remodel" → App suggests Home Maintenance template',
              Icons.lightbulb_outline,
              Colors.orange,
            ),

            _buildFeatureCard(
              context,
              '⚡ Instant Task Creation',
              'Choose template → Get 5-8 pre-made tasks automatically',
              Icons.flash_on,
              Colors.blue,
            ),

            _buildFeatureCard(
              context,
              '📚 5 Built-in Templates',
              'Project Workflow, Shopping, Travel, Home Maintenance, Events',
              Icons.folder_copy,
              Colors.purple,
            ),

            const SizedBox(height: 24),

            // Templates status
            Text(
              '📋 Available Templates',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            templatesAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Error loading templates: $error'),
              ),
              data: (templates) => Column(
                children: templates.map((template) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      Icons.folder_copy_outlined,
                      color: template.isBuiltIn ? Colors.blue : Colors.green,
                    ),
                    title: Text(template.name),
                    subtitle: Text(
                      '${template.taskTemplates.length} tasks • ${template.isBuiltIn ? 'Built-in' : 'Custom'}'
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('Used ${template.useCount}x'),
                    ),
                  ),
                )).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // Demo section
            Text(
              '🚀 Try It Out',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 Demo Instructions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Click "Create Test Folder" below\n'
                    '2. Try these names to trigger suggestions:\n'
                    '   • "Kitchen Project" → Home Maintenance\n'
                    '   • "Client Website" → Project Workflow\n'
                    '   • "Birthday Party" → Event Planning\n'
                    '   • "Grocery Shopping" → Shopping Trip\n'
                    '3. Watch template suggestion dialog appear\n'
                    '4. Select template → See tasks auto-created!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _showCreateFolderDemo(context),
                icon: const Icon(Icons.add),
                label: const Text('Create Test Folder'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, String title, String description, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
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

  void _showCreateFolderDemo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateFolderDialog(),
    );
  }
}
