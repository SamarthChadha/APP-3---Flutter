import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class TimePickerSheet extends StatelessWidget {
  final TimeOfDay initial;
  final ValueChanged<TimeOfDay> onChanged;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const TimePickerSheet({
    super.key,
    required this.initial,
    required this.onChanged,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: 300,
        decoration: BoxDecoration(
          color: CupertinoTheme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    onPressed: onCancel,
                    child: const Text('Cancel'),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    onPressed: onSave,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                minuteInterval: 1,
                use24hFormat: MediaQuery.of(context).alwaysUse24HourFormat,
                initialDateTime: DateTime(0, 1, 1, initial.hour, initial.minute),
                onDateTimeChanged: (DateTime v) {
                  onChanged(TimeOfDay(hour: v.hour, minute: v.minute));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
