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

  ApiClient get api => widget.session.api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      data = await api.week();
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
                      const Text(
                        'Macros are estimated from ingredients and scaled to your household.',
                        style: TextStyle(color: kMuted),
                      ),
                      const SizedBox(height: 12),
                      for (final day in (data?['days'] as List? ?? []))
                        _DayCard(
                          day: day as Map<String, dynamic>,
                          onCooked: _cooked,
                          onRemove: (id) async {
                            await api.removeSlot(id);
                            await _load();
                          },
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.onCooked, required this.onRemove});
  final Map<String, dynamic> day;
  final Future<void> Function(Map<String, dynamic> slot) onCooked;
  final Future<void> Function(String id) onRemove;

  @override
  Widget build(BuildContext context) {
    final slots = (day['slots'] as List? ?? []).cast<Map<String, dynamic>>();
    final macros = (day['macros'] as Map<String, dynamic>?) ?? {};
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(day['date'] as String, style: const TextStyle(fontWeight: FontWeight.w700, color: kGreen)),
            const SizedBox(height: 8),
            MacrosRow(macros: macros, compact: true),
            const SizedBox(height: 8),
            if (slots.isEmpty)
              const Text('Nothing planned.', style: TextStyle(color: kMuted))
            else
              for (final slot in slots)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${slot['slot']} · ${(slot['recipe'] as Map)['title']}'),
                  subtitle: Text(slot['cooked'] == true ? 'Cooked' : 'On the plan'),
                  trailing: Wrap(
                    children: [
                      if (slot['cooked'] != true)
                        IconButton(
                          tooltip: 'Mark cooked',
                          onPressed: () => onCooked(slot),
                          icon: const Icon(Icons.check_circle_outline, color: kGreen),
                        ),
                      IconButton(
                        tooltip: 'Remove',
                        onPressed: () => onRemove(slot['id'] as String),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
