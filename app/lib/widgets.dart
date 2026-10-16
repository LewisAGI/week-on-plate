import 'package:flutter/material.dart';

import 'domain/method.dart';
import 'theme.dart';

const slotOrder = ['breakfast', 'lunch', 'dinner', 'snack'];

String slotLabel(String slot) {
  final s = slot.trim();
  if (s.isEmpty) return s;
  return '${s[0].toUpperCase()}${s.substring(1)}';
}

IconData slotIcon(String slot) {
  switch (slot) {
    case 'breakfast':
      return Icons.wb_sunny_outlined;
    case 'lunch':
      return Icons.lunch_dining_outlined;
    case 'snack':
      return Icons.cookie_outlined;
    default:
      return Icons.dinner_dining_outlined;
  }
}

String weekdayShort(String ymd) {
  final parts = ymd.split('-');
  if (parts.length < 3) return ymd;
  final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return names[dt.weekday - 1];
}

String weekdayLetter(String ymd) => weekdayShort(ymd).substring(0, 1);

int dayNumber(String ymd) {
  final parts = ymd.split('-');
  if (parts.length < 3) return 0;
  return int.tryParse(parts[2]) ?? 0;
}

String localYmd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String formatThousands(num value) {
  final rounded = value.round();
  final negative = rounded < 0;
  final digits = rounded.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return negative ? '-$buf' : buf.toString();
}

String dayHeaderLabel(String ymd, num kcal) => '${weekdayShort(ymd)} · ${formatThousands(kcal)} kcal';

num macroNum(Map<String, dynamic> macros, String key) {
  final v = macros[key];
  if (v is num) return v;
  return num.tryParse('$v') ?? 0;
}

List<Map<String, dynamic>> slotsInMealOrder(List<Map<String, dynamic>> slots) {
  final copy = [...slots];
  copy.sort((a, b) {
    final ai = slotOrder.indexOf('${a['slot']}');
    final bi = slotOrder.indexOf('${b['slot']}');
    return (ai < 0 ? 99 : ai).compareTo(bi < 0 ? 99 : bi);
  });
  return copy;
}

String aisleForName(String name) {
  final n = name.toLowerCase();
  const produce = [
    'lemon',
    'onion',
    'garlic',
    'spinach',
    'tomato',
    'potato',
    'berr',
    'broccoli',
    'apple',
    'banana',
    'herb',
    'salad',
    'pepper',
    'cucumber',
    'lettuce',
    'avocado',
  ];
  const dairy = ['milk', 'yoghurt', 'yogurt', 'cheese', 'butter', 'egg', 'cream'];
  const protein = ['chicken', 'salmon', 'turkey', 'beef', 'fish', 'mince', 'tofu', 'prawn'];
  const bakery = ['bread', 'flour', 'oat', 'rice', 'pasta', 'wrap', 'tortilla'];
  bool has(List<String> keys) => keys.any(n.contains);
  if (has(produce)) return 'Produce';
  if (has(dairy)) return 'Dairy & eggs';
  if (has(protein)) return 'Meat & fish';
  if (has(bakery)) return 'Bakery & grains';
  return 'Cupboard';
}

class IconTip extends StatelessWidget {
  const IconTip({
    super.key,
    required this.message,
    required this.icon,
    required this.onPressed,
  });

  final String message;
  final Widget icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.longPress,
      child: IconButton(onPressed: onPressed, icon: icon),
    );
  }
}

class OutlinedAddButton extends StatelessWidget {
  const OutlinedAddButton({super.key, required this.onPressed, this.message = 'Add'});

  final VoidCallback? onPressed;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.longPress,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: kGreen,
          side: const BorderSide(color: kGreen, width: 1.4),
          minimumSize: const Size(36, 36),
          maximumSize: const Size(36, 36),
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onPressed,
        child: const Icon(Icons.add, size: 20),
      ),
    );
  }
}

class FoodThumb extends StatelessWidget {
  const FoodThumb({super.key, required this.seed, this.borderRadius = 12});

  final String seed;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final hash = seed.codeUnits.fold<int>(0, (a, b) => (a * 33 + b) & 0x7fffffff);
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CustomPaint(
        painter: _FoodPainter(hash),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _FoodPainter extends CustomPainter {
  _FoodPainter(this.hash);
  final int hash;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = kGreenSoft;
    canvas.drawRect(Offset.zero & size, bg);
    final plate = Paint()..color = kWhite;
    final cx = size.width * 0.5;
    final cy = size.height * 0.56;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: size.width * 0.72, height: size.height * 0.42),
      plate,
    );
    final food = Paint()..color = hash % 3 == 0 ? kGreenDark : kGreen;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - size.width * 0.08, cy - size.height * 0.02), width: size.width * 0.34, height: size.height * 0.22),
        const Radius.circular(8),
      ),
      food,
    );
    final accent = Paint()..color = kGreen;
    canvas.drawCircle(Offset(cx + size.width * 0.16, cy - size.height * 0.04), size.width * 0.09, accent);
    canvas.drawCircle(Offset(cx + size.width * 0.02, cy + size.height * 0.08), size.width * 0.06, Paint()..color = kGreenDark);
  }

  @override
  bool shouldRepaint(covariant _FoodPainter oldDelegate) => oldDelegate.hash != hash;
}

class WeekFullnessGrid extends StatelessWidget {
  const WeekFullnessGrid({
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
    return Row(
      children: [
        for (final day in days)
          Expanded(
            child: _FullnessColumn(
              day: day,
              selected: day['date'] == selectedDate,
              onTap: () => onSelect(day['date'] as String),
            ),
          ),
      ],
    );
  }
}

class _FullnessColumn extends StatelessWidget {
  const _FullnessColumn({required this.day, required this.selected, required this.onTap});

  final Map<String, dynamic> day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = day['date'] as String;
    final slots = (day['slots'] as List? ?? []).cast<Map<String, dynamic>>();
    final filled = {for (final s in slots) '${s['slot']}'};
    return Tooltip(
      message: weekdayShort(date),
      triggerMode: TooltipTriggerMode.longPress,
      child: Material(
        color: kWhite,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? kGreen : const Color(0xFFE3EDE7), width: selected ? 1.6 : 1),
            ),
            child: Column(
              children: [
                for (final slot in slotOrder.reversed)
                  Container(
                    height: 8,
                    margin: const EdgeInsets.only(bottom: 3),
                    decoration: BoxDecoration(
                      color: filled.contains(slot) ? kGreen : const Color(0xFFE3EDE7),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  weekdayLetter(date),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? kGreen : kMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CompactMealCard extends StatelessWidget {
  const CompactMealCard({
    super.key,
    required this.slot,
    required this.onCooked,
    required this.onRemove,
    this.onOpen,
  });

  final Map<String, dynamic> slot;
  final VoidCallback onCooked;
  final VoidCallback onRemove;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final recipe = (slot['recipe'] as Map<String, dynamic>?) ?? {};
    final cooked = slot['cooked'] == true;
    final title = recipe['title'] as String? ?? 'Meal';
    final minutes = recipe['minutes'];
    final macros = (slot['macros'] as Map<String, dynamic>?) ??
        (recipe['scaled_macros'] as Map<String, dynamic>?) ??
        {};
    final kcal = formatThousands(macroNum(macros, 'kcal'));
    final slotName = '${slot['slot'] ?? ''}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
          child: Row(
            children: [
              SizedBox(width: 64, height: 64, child: FoodThumb(seed: title)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: cooked ? kMuted : kInk,
                        decoration: cooked ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (minutes != null) _MealMeta(icon: Icons.schedule, label: '$minutes min'),
                        _MealMeta(icon: Icons.local_fire_department_outlined, label: '$kcal kcal', iconColor: kGreen),
                        _MealMeta(icon: slotIcon(slotName), label: slotLabel(slotName)),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Meal actions',
                icon: const Icon(Icons.more_vert, color: kMuted),
                onSelected: (value) {
                  if (value == 'cooked') onCooked();
                  if (value == 'remove') onRemove();
                  if (value == 'open') onOpen?.call();
                },
                itemBuilder: (context) => [
                  if (!cooked)
                    const PopupMenuItem(value: 'cooked', child: Text('Mark cooked')),
                  if (onOpen != null)
                    const PopupMenuItem(value: 'open', child: Text('Open recipe')),
                  const PopupMenuItem(value: 'remove', child: Text('Remove')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MealMeta extends StatelessWidget {
  const _MealMeta({required this.icon, required this.label, this.iconColor = kMuted});

  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(color: kMuted, fontSize: 13)),
      ],
    );
  }
}

class MacroCard extends StatelessWidget {
  const MacroCard({super.key, required this.macros});

  final Map<String, dynamic> macros;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, String value) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: kInk)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: kMuted, fontSize: 12)),
        ],
      );
    }

    String n(String key, {bool grams = false}) {
      final v = macros[key];
      if (v == null) return '–';
      final shown = v is num ? formatThousands(v) : '$v';
      return grams ? '${shown}g' : shown;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            cell('kcal', n('kcal')),
            cell('Protein', n('protein', grams: true)),
            cell('Carbs', n('carbs', grams: true)),
            cell('Fat', n('fat', grams: true)),
          ],
        ),
      ),
    );
  }
}

class MethodStepsList extends StatelessWidget {
  const MethodStepsList({super.key, required this.steps});

  final List<String> steps;

  factory MethodStepsList.fromRecipe(Map<String, dynamic> recipe) {
    return MethodStepsList(steps: stepsFromRecipe(recipe));
  }

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const Text('No method written yet.', style: TextStyle(color: kMuted));
    }
    return Stack(
      children: [
        Positioned(
          left: 13,
          top: 16,
          bottom: 16,
          child: Container(width: 2, color: const Color(0xFFE3EDE7)),
        ),
        Column(
          children: [
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: kInk, shape: BoxShape.circle),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(steps[i], style: const TextStyle(height: 1.35, fontSize: 15, color: kInk)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class ServingsStepper extends StatelessWidget {
  const ServingsStepper({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Servings', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: kInk)),
        const Spacer(),
        IconTip(
          message: 'Fewer servings',
          onPressed: value <= 1 ? null : () => onChanged(value - 1),
          icon: const Icon(Icons.remove, color: kGreen),
        ),
        Container(
          width: 42,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: kGreenSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$value', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ),
        IconTip(
          message: 'More servings',
          onPressed: value >= 24 ? null : () => onChanged(value + 1),
          icon: const Icon(Icons.add, color: kGreen),
        ),
      ],
    );
  }
}

class CheckLine extends StatelessWidget {
  const CheckLine({
    super.key,
    required this.title,
    required this.quantity,
    required this.checked,
    required this.struck,
    required this.onChanged,
  });

  final String title;
  final String quantity;
  final bool checked;
  final bool struck;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      fontSize: 16,
      color: struck ? kMuted : kInk,
      decoration: struck ? TextDecoration.lineThrough : null,
      decorationColor: kMuted,
    );
    return Opacity(
      opacity: struck ? 0.45 : 1,
      child: InkWell(
        onTap: () => onChanged(!checked),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: Checkbox(
                  value: checked,
                  activeColor: kGreen,
                  onChanged: (v) => onChanged(v ?? false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: titleStyle)),
              if (quantity.isNotEmpty)
                Text(
                  quantity,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: kGreen, fontSize: 15),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddLine extends StatelessWidget {
  const AddLine({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.add, color: kGreen),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: kMuted, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class SlotPickerSheet extends StatelessWidget {
  const SlotPickerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          const Text('Sitting', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          for (final slot in slotOrder)
            ListTile(
              leading: Icon(slotIcon(slot), color: kGreen),
              title: Text(slotLabel(slot)),
              onTap: () => Navigator.pop(context, slot),
            ),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 12),
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
  final shown = q == null
      ? '$quantity'
      : (q == q.roundToDouble() ? formatThousands(q) : '$q');
  if (unit == null || unit == 'each') return shown;
  return '$shown$unit';
}

List<Map<String, dynamic>> scaledIngredients(Map<String, dynamic> recipe, int servings) {
  final baseServes = (recipe['serves'] as num?)?.toDouble() ?? 1;
  final factor = baseServes <= 0 ? 1.0 : servings / baseServes;
  final source = (recipe['ingredients'] as List?) ?? (recipe['scaled_ingredients'] as List?) ?? [];
  return [
    for (final raw in source.cast<Map<String, dynamic>>())
      {
        ...raw,
        'quantity': raw['quantity'] is num ? (raw['quantity'] as num) * factor : raw['quantity'],
      },
  ];
}

Map<String, dynamic> scaledMacros(Map<String, dynamic> recipe, int servings) {
  final baseServes = (recipe['serves'] as num?)?.toDouble() ?? 1;
  final factor = baseServes <= 0 ? 1.0 : servings / baseServes;
  final macros = (recipe['macros'] as Map<String, dynamic>?) ??
      (recipe['scaled_macros'] as Map<String, dynamic>?) ??
      {};
  return {
    for (final key in ['kcal', 'protein', 'carbs', 'fat', 'sugar'])
      key: macroNum(macros, key) * factor,
  };
}
