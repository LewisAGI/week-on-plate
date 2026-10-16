import 'package:flutter/material.dart';

import '../api/api.dart';
import '../state/session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'recipes_screen.dart';

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
  final expanded = <String, bool>{};
  final dayKeys = <String, GlobalKey>{};
  List<Map<String, dynamic>> recipes = [];

  ApiClient get api => widget.session.api;

  List<Map<String, dynamic>> get days =>
      (data?['days'] as List? ?? []).cast<Map<String, dynamic>>();

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
    for (final day in days) {
      final date = day['date'] as String;
      dayKeys.putIfAbsent(date, GlobalKey.new);
      expanded.putIfAbsent(date, () => true);
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

  Future<List<Map<String, dynamic>>> _ensureRecipes() async {
    if (recipes.isNotEmpty) return recipes;
    final data = await api.recipes();
    recipes = (data['recipes'] as List? ?? []).cast<Map<String, dynamic>>();
    return recipes;
  }

  void _jump(String date) {
    setState(() => selectedDate = date);
    final ctx = dayKeys[date]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 280), alignment: 0.02);
    }
  }

  Future<void> _add(String date) async {
    List<Map<String, dynamic>> list;
    try {
      list = await _ensureRecipes();
    } catch (e) {
      if (mounted) await showMessage(context, e.toString());
      return;
    }
    if (!mounted) return;
    final recipe = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => RecipePickerSheet(recipes: list),
    );
    if (recipe == null || !mounted) return;
    final slot = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const SlotPickerSheet(),
    );
    if (slot == null) return;
    await api.addToWeek(date: date, slot: slot, recipeId: recipe['id'] as String);
    await _load();
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

  Future<void> _openRecipe(Map<String, dynamic> slot) async {
    final recipe = slot['recipe'] as Map<String, dynamic>?;
    final id = recipe?['id'] as String?;
    if (id == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecipeDetailScreen(session: widget.session, recipeId: id),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('This week'),
        actions: [
          IconTip(message: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? EmptyHint(text: error!)
              : WeekPage(
                  days: days,
                  selectedDate: selectedDate ?? (days.isEmpty ? '' : days.first['date'] as String),
                  expanded: expanded,
                  dayKeys: dayKeys,
                  onSelectDay: _jump,
                  onToggleDay: (date) => setState(() => expanded[date] = !(expanded[date] ?? true)),
                  onAdd: _add,
                  onCooked: _cooked,
                  onRemove: (slot) async {
                    await api.removeSlot(slot['id'] as String);
                    await _load();
                  },
                  onOpen: _openRecipe,
                  onRefresh: _load,
                ),
    );
  }
}

class WeekPage extends StatelessWidget {
  const WeekPage({
    super.key,
    required this.days,
    required this.selectedDate,
    required this.expanded,
    required this.onSelectDay,
    required this.onToggleDay,
    required this.onAdd,
    required this.onCooked,
    required this.onRemove,
    required this.onOpen,
    this.onRefresh,
    this.dayKeys = const {},
  });

  final List<Map<String, dynamic>> days;
  final String selectedDate;
  final Map<String, bool> expanded;
  final Map<String, GlobalKey> dayKeys;
  final ValueChanged<String> onSelectDay;
  final ValueChanged<String> onToggleDay;
  final ValueChanged<String> onAdd;
  final ValueChanged<Map<String, dynamic>> onCooked;
  final ValueChanged<Map<String, dynamic>> onRemove;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          if (days.isEmpty)
            const EmptyHint(text: 'Nothing planned.')
          else
            for (final day in days)
              _DayBlock(
                key: dayKeys[day['date'] as String],
                day: day,
                expanded: expanded[day['date'] as String] ?? true,
                onToggle: () => onToggleDay(day['date'] as String),
                onAdd: () => onAdd(day['date'] as String),
                onCooked: onCooked,
                onRemove: onRemove,
                onOpen: onOpen,
              ),
        ],
      ),
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: WeekFullnessGrid(days: days, selectedDate: selectedDate, onSelect: onSelectDay),
        ),
        Expanded(child: list),
      ],
    );
  }
}

class _DayBlock extends StatelessWidget {
  const _DayBlock({
    super.key,
    required this.day,
    required this.expanded,
    required this.onToggle,
    required this.onAdd,
    required this.onCooked,
    required this.onRemove,
    required this.onOpen,
  });

  final Map<String, dynamic> day;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onAdd;
  final ValueChanged<Map<String, dynamic>> onCooked;
  final ValueChanged<Map<String, dynamic>> onRemove;
  final ValueChanged<Map<String, dynamic>> onOpen;

  @override
  Widget build(BuildContext context) {
    final date = day['date'] as String;
    final macros = (day['macros'] as Map<String, dynamic>?) ?? {};
    final slots = slotsInMealOrder((day['slots'] as List? ?? []).cast<Map<String, dynamic>>());
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onToggle,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Icon(expanded ? Icons.expand_more : Icons.chevron_right, color: kInk, size: 22),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            dayHeaderLabel(date, macroNum(macros, 'kcal')),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: kInk),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              OutlinedAddButton(message: 'Add a meal', onPressed: onAdd),
            ],
          ),
          if (expanded) ...[
            if (slots.isEmpty)
              const EmptyHint(text: 'Nothing planned.')
            else
              for (final slot in slots)
                CompactMealCard(
                  slot: slot,
                  onCooked: () => onCooked(slot),
                  onRemove: () => onRemove(slot),
                  onOpen: () => onOpen(slot),
                ),
          ],
        ],
      ),
    );
  }
}

class RecipePickerSheet extends StatefulWidget {
  const RecipePickerSheet({super.key, required this.recipes});

  final List<Map<String, dynamic>> recipes;

  @override
  State<RecipePickerSheet> createState() => _RecipePickerSheetState();
}

class _RecipePickerSheetState extends State<RecipePickerSheet> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final shown = widget.recipes.where((r) {
      final title = (r['title'] as String? ?? '').toLowerCase();
      return query.trim().isEmpty || title.contains(query.trim().toLowerCase());
    }).toList();
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.62,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE3EDE7), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Add a meal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search recipes',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => query = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: shown.isEmpty
                  ? const EmptyHint(text: 'No recipes match.')
                  : ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (context, i) {
                        final recipe = shown[i];
                        final title = recipe['title'] as String? ?? 'Recipe';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: SizedBox(width: 48, height: 48, child: FoodThumb(seed: title, borderRadius: 10)),
                          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            [
                              if (recipe['minutes'] != null) '${recipe['minutes']} min',
                              'Serves ${recipe['serves'] ?? '–'}',
                            ].join(' · '),
                          ),
                          onTap: () => Navigator.pop(context, recipe),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

