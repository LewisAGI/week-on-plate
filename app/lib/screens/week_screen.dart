import 'package:flutter/material.dart';

import '../api/api.dart';
import '../state/session.dart';
import '../theme.dart';
import '../widgets.dart';

class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key, required this.session});
  final Session session;

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  Map<String, dynamic>? data;
  String? error;
  bool loading = true;
  String? selectedDate;

  ApiClient get api => widget.session.api;

  List<Map<String, dynamic>> get days =>
      (data?['days'] as List? ?? []).cast<Map<String, dynamic>>();

  Map<String, dynamic>? get selectedDay {
    if (days.isEmpty) return null;
    return days.cast<Map<String, dynamic>?>().firstWhere(
          (d) => d?['date'] == selectedDate,
          orElse: () => days.first,
        );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _focusDefaultDay() {
    if (days.isEmpty) {
      selectedDate = null;
      return;
    }
    if (selectedDate != null && days.any((d) => d['date'] == selectedDate)) return;
    final today = localYmd(DateTime.now());
    selectedDate = days.any((d) => d['date'] == today) ? today : days.first['date'] as String;
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      data = await api.week();
      _focusDefaultDay();
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _cooked(Map<String, dynamic> slot) async {
    final result = await api.markCooked(slot['id'] as String);
    final suggestions = (result['suggestions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (!mounted) return;
    if (suggestions.isEmpty) {
      await showMessage(context, 'Marked as cooked.');
      await _load();
      return;
    }
    final apply = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update the cupboard?'),
        content: SingleChildScrollView(
          child: Text(
            suggestions
                .where((s) => s['action'] != 'none')
                .map((s) => '${s['name']}: ${s['reason']}')
                .join('\n'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, adjust')),
        ],
      ),
    );
    if (apply == true) {
      await api.adjustCupboard(suggestions.where((s) => s['action'] != 'none').toList());
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final day = selectedDay;
    final slots = slotsInMealOrder((day?['slots'] as List? ?? []).cast<Map<String, dynamic>>());
    final macros = (day?['macros'] as Map<String, dynamic>?) ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('This week'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? EmptyHint(text: error!)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      WeekDayStrip(
                        days: days,
                        selectedDate: selectedDate ?? (days.isEmpty ? '' : days.first['date'] as String),
                        onSelect: (date) => setState(() => selectedDate = date),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        day == null
                            ? 'Daily totals'
                            : '${weekdayShort(day['date'] as String)} totals',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: kGreen, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Sum of the meal cards on this day, scaled to your household.',
                        style: TextStyle(color: kMuted),
                      ),
                      const SizedBox(height: 8),
                      MacrosRow(macros: macros),
                      const SizedBox(height: 20),
                      if (slots.isEmpty)
                        EmptyHint(
                          text: day == null
                              ? 'Nothing planned.'
                              : 'Nothing planned for ${weekdayShort(day['date'] as String)}.',
                        )
                      else
                        for (final slot in slots)
                          MealPlanCard(
                            slot: slot,
                            onCooked: () => _cooked(slot),
                            onRemove: () async {
                              await api.removeSlot(slot['id'] as String);
                              await _load();
                            },
                          ),
                    ],
                  ),
                ),
    );
  }
}

class MealPlanCard extends StatelessWidget {
  const MealPlanCard({
    super.key,
    required this.slot,
    required this.onCooked,
    required this.onRemove,
  });

  final Map<String, dynamic> slot;
  final VoidCallback onCooked;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final recipe = (slot['recipe'] as Map<String, dynamic>?) ?? {};
    final cooked = slot['cooked'] == true;
    final ingredients = (recipe['scaled_ingredients'] as List? ?? []).cast<Map<String, dynamic>>();
    final macros = (slot['macros'] as Map<String, dynamic>?) ??
        (recipe['scaled_macros'] as Map<String, dynamic>?) ??
        {};

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  slotLabel('${slot['slot'] ?? ''}'),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: kGreen, fontSize: 13),
                ),
                const Spacer(),
                Text(
                  cooked ? 'Cooked' : 'On the plan',
                  style: TextStyle(color: cooked ? kGreen : kMuted, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              recipe['title'] as String? ?? 'Meal',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: kInk),
            ),
            if ((recipe['summary'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(recipe['summary'] as String, style: const TextStyle(color: kMuted, height: 1.35)),
            ],
            const SizedBox(height: 10),
            MacrosRow(macros: macros, compact: true),
            if (ingredients.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Ingredients', style: TextStyle(fontWeight: FontWeight.w700, color: kGreen)),
              const SizedBox(height: 4),
              for (final ing in ingredients)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '• ${qtyLabel(ing['quantity'], ing['unit'] as String?)} ${ing['name']}'.trim(),
                    style: const TextStyle(height: 1.35),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            const Text('Method', style: TextStyle(fontWeight: FontWeight.w700, color: kGreen)),
            const SizedBox(height: 4),
            MethodStepsList.fromRecipe(recipe, compact: true),
            const SizedBox(height: 8),
            Row(
              children: [
                if (!cooked)
                  TextButton.icon(
                    onPressed: onCooked,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Mark cooked'),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
