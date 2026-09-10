import 'package:flutter/material.dart';

import 'theme.dart';

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
