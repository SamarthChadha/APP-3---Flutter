import 'package:flutter/material.dart';

class AlarmDurationSelector extends StatelessWidget {
  final int value; // minutes
  final ValueChanged<int> onChanged;
  final List<int> options;

  const AlarmDurationSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.options = const [10, 20, 30],
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.map((opt) {
        final selected = value == opt;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: selected ? const Color(0xFFFFC049) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onChanged(opt),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? const Color(0xFFFFC049) : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (selected) ...[
                        const Icon(Icons.check, size: 16, color: Color(0xFF3C3C3C)),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        '${opt}m',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected ? const Color(0xFF3C3C3C) : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
