import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Demo widget showing how to implement a time picker with TextFormField
/// that automatically respects regional settings (24-hour vs AM/PM format)
class TimePickerDemo extends StatefulWidget {
  const TimePickerDemo({super.key});

  @override
  State<TimePickerDemo> createState() => _TimePickerDemoState();
}

class _TimePickerDemoState extends State<TimePickerDemo> {
  final _formKey = GlobalKey<FormState>();
  final _timeController = TextEditingController();
  TimeOfDay? _selectedTime;
  DateTime? _selectedDate;

  @override
  void dispose() {
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final use24HourFormat = MediaQuery.of(context).alwaysUse24HourFormat;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Picker Demo'),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info card showing current format
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📱 Regional Settings Detected',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your device uses: ${use24HourFormat ? '24-hour format (14:30)' : '12-hour format (2:30 PM)'}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Date picker (for context)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(PhosphorIcons.calendar()),
                title: Text(_selectedDate == null 
                    ? 'Select date first' 
                    : 'Date: ${_formatDate(_selectedDate!)}'),
                trailing: _selectedDate != null 
                    ? IconButton(
                        icon: Icon(PhosphorIcons.x()),
                        onPressed: () => setState(() {
                          _selectedDate = null;
                          _selectedTime = null;
                          _timeController.clear();
                        }),
                      )
                    : null,
                onTap: _selectDate,
              ),
              
              const SizedBox(height: 16),
              
              // Time picker TextFormField (only show if date is selected)
              if (_selectedDate != null) ...[
                TextFormField(
                  controller: _timeController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Select Time',
                    hintText: 'Tap to choose time',
                    prefixIcon: Icon(PhosphorIcons.clock()),
                    suffixIcon: _selectedTime != null 
                        ? IconButton(
                            icon: Icon(PhosphorIcons.x(), size: 18),
                            onPressed: () {
                              setState(() {
                                _selectedTime = null;
                                _timeController.clear();
                              });
                            },
                            tooltip: 'Clear time',
                          )
                        : Icon(PhosphorIcons.caretDown(), size: 16),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                  onTap: _selectTime,
                  validator: (value) {
                    if (_selectedTime != null && _selectedDate != null) {
                      final now = DateTime.now();
                      final selectedDateTime = DateTime(
                        _selectedDate!.year,
                        _selectedDate!.month,
                        _selectedDate!.day,
                        _selectedTime!.hour,
                        _selectedTime!.minute,
                      );
                      
                      if (selectedDateTime.isBefore(now)) {
                        return 'Selected time cannot be in the past';
                      }
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Quick time selection chips
                const Text(
                  'Quick Selection:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildTimeChip('9:00 AM', const TimeOfDay(hour: 9, minute: 0)),
                    _buildTimeChip('12:00 PM', const TimeOfDay(hour: 12, minute: 0)),
                    _buildTimeChip('3:00 PM', const TimeOfDay(hour: 15, minute: 0)),
                    _buildTimeChip('6:00 PM', const TimeOfDay(hour: 18, minute: 0)),
                    _buildTimeChip('9:00 PM', const TimeOfDay(hour: 21, minute: 0)),
                  ],
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Result display
              if (_selectedTime != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '✅ Selected Date & Time',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text('Date: ${_formatDate(_selectedDate!)}'),
                        Text('Time: ${_formatTime(_selectedTime!)}'),
                        Text('Format: ${use24HourFormat ? '24-hour' : '12-hour AM/PM'}'),
                        const SizedBox(height: 8),
                        Text(
                          'Combined: ${_formatDateTime()}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Validate button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selectedTime != null 
                      ? () {
                          if (_formKey.currentState!.validate()) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✅ Time validation passed: ${_formatTime(_selectedTime!)}'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }
                      : null,
                  child: const Text('Validate Selection'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null) {
      setState(() {
        _selectedDate = date;
        // Clear time when date changes
        _selectedTime = null;
        _timeController.clear();
      });
    }
  }

  Future<void> _selectTime() async {
    if (_selectedDate == null) return;
    
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              timePickerTheme: TimePickerThemeData(
                backgroundColor: Theme.of(context).colorScheme.surface,
                hourMinuteShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                dayPeriodShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                inputDecorationTheme: InputDecorationTheme(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            child: child!,
          ),
        );
      },
    );
    
    if (time != null) {
      setState(() {
        _selectedTime = time;
        _timeController.text = _formatTime(time);
      });
    }
  }

  Widget _buildTimeChip(String label, TimeOfDay time) {
    final isSelected = _selectedTime == time;
    
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isSelected 
              ? Theme.of(context).colorScheme.onPrimaryContainer
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedTime = selected ? time : null;
          _timeController.text = selected ? _formatTime(time) : '';
        });
      },
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      backgroundColor: Theme.of(context).colorScheme.surface,
      checkmarkColor: Theme.of(context).colorScheme.primary,
      side: BorderSide(
        color: isSelected 
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline.withAlpha(128),
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final use24HourFormat = MediaQuery.of(context).alwaysUse24HourFormat;
    
    if (use24HourFormat) {
      // 24-hour format: "14:30"
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      // 12-hour format with AM/PM: "2:30 PM"
      final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
      final minute = time.minute.toString().padLeft(2, '0');
      final period = time.period == DayPeriod.am ? 'AM' : 'PM';
      return '$hour:$minute $period';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime() {
    if (_selectedDate == null || _selectedTime == null) return '';
    
    final dateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    
    return '${_formatDate(dateTime)} at ${_formatTime(_selectedTime!)}';
  }
}
