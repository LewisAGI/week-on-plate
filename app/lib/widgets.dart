import 'package:flutter/material.dart';

import 'domain/method.dart';
import 'theme.dart';

const slotOrder = ['breakfast', 'lunch', 'dinner', 'snack'];

String slotLabel(String slot) {
  final s = slot.trim();
  if (s.isEmpty) return s;
  return '${s[0].toUpperCase()}${s.substring(1)}';
}

String weekdayShort(String ymd) {
  final parts = ymd.split('-');
  if (parts.length < 3) return ymd;
  final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return names[dt.weekday - 1];
}

int dayNumber(String ymd) {
  final parts = ymd.split('-');
  if (parts.length < 3) return 0;
  return int.tryParse(parts[2]) ?? 0;
}

String localYmd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

List<Map<String, dynamic>> slotsInMealOrder(List<Map<String, dynamic>> slots) {
  final copy = [...slots];
  copy.sort((a, b) {
    final ai = slotOrder.indexOf('${a['slot']}');
    final bi = slotOrder.indexOf('${b['slot']}');
    return (ai < 0 ? 99 : ai).compareTo(bi < 0 ? 99 : bi);
  });
  return copy;
}

class MacrosRow extends StatelessWidget {
  const MacrosRow({super.key, required this.macros, this.compact = false});

  final Map<String, dynamic> macros;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    String n(String k) {
      final v = macros[k];
      if (v == null) return '–';
      if (v is num) return v.round().toString();
      return '$v';
    }

    final items = [
      ('kcal', n('kcal')),
      ('protein', '${n('protein')}g'),
      ('carbs', '${n('carbs')}g'),
      ('fat', '${n('fat')}g'),
      ('sugar', '${n('sugar')}g'),
    ];
    return Wrap(
      spacing: compact ? 8 : 12,
      runSpacing: 6,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: kGreenSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${item.$1} ${item.$2}',
              style: TextStyle(
                color: kGreenDark,
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class MethodStepsList extends StatelessWidget {
  const MethodStepsList({super.key, required this.steps, this.compact = false});

  final List<String> steps;
  final bool compact;

  factory MethodStepsList.fromRecipe(Map<String, dynamic> recipe, {bool compact = false}) {
    return MethodStepsList(steps: stepsFromRecipe(recipe), compact: compact);
  }

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const Text('No method written yet.', style: TextStyle(color: kMuted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: compact ? 4 : 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: compact ? 22 : 28,
                  child: Text(
                    '${i + 1}.',
                    style: TextStyle(
                      color: kGreen,
                      fontWeight: FontWeight.w700,
                      fontSize: compact ? 13 : 15,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    steps[i],
                    style: TextStyle(height: 1.35, fontSize: compact ? 13 : 15, color: kInk),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class WeekDayStrip extends StatelessWidget {
  const WeekDayStrip({
    super.key,
    required this.days,
    required this.selectedDate,
    required this.onSelect,
  });

  final List<Map<String, dynamic>> days;
  final String selectedDate;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final today = localYmd(DateTime.now());
    return Row(
      children: [
        for (final day in days)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _DayChip(
                date: day['date'] as String,
                selected: day['date'] == selectedDate,
                isToday: day['date'] == today,
                onTap: () => onSelect(day['date'] as String),
              ),
            ),
          ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.date,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final String date;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? kGreen : kGreenSoft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Text(
                weekdayShort(date),
                style: TextStyle(
                  color: selected ? kWhite : kGreenDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${dayNumber(date)}',
                style: TextStyle(
                  color: selected ? kWhite : kInk,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              if (isToday)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 14,
                  height: 3,
                  decoration: BoxDecoration(
                    color: selected ? kWhite : kGreen,
                    borderRadius: BorderRadius.circular(2),
                  ),
                )
              else
                const SizedBox(height: 7),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyHint extends StatelessWidget {
  const EmptyHint({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, style: const TextStyle(color: kMuted, height: 1.4)),
    );
  }
}

Future<void> showMessage(BuildContext context, String text) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('WeekOnPlate'),
      content: Text(text),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
      ],
    ),
  );
}

String money(int pence) {
  final pounds = pence / 100;
  return '£${pounds.toStringAsFixed(pence % 100 == 0 ? 0 : 2)}';
}

String qtyLabel(dynamic quantity, String? unit) {
  if (quantity == null) return unit == null || unit == 'each' ? '' : unit;
  final q = quantity is num ? quantity : num.tryParse('$quantity');
  final shown = q == null ? '$quantity' : (q == q.roundToDouble() ? '${q.round()}' : '$q');
  if (unit == null || unit == 'each') return shown;
  return '$shown$unit';
}
