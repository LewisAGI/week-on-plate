import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/shopping.dart';
import '../state/session.dart';
import '../theme.dart';
import '../widgets.dart';

class GroceryLine {
  GroceryLine({
    required this.keyId,
    required this.name,
    required this.quantity,
    required this.aisle,
    required this.meal,
  });

  final String keyId;
  final String name;
  final String quantity;
  final String aisle;
  final String meal;
  bool ticked = false;
}

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key, required this.session});
  final Session session;

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  final lines = <GroceryLine>[];
  final manual = <GroceryLine>[];
  String? error;
  bool loading = true;
  String groupBy = 'aisle';

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
      final shopping = await widget.session.api.shopping();
      Map<String, dynamic>? week;
      try {
        week = await widget.session.api.week();
      } catch (_) {
        week = null;
      }
      final meals = _mealsByName(week);
      final ticks = {for (final line in lines) line.keyId: line.ticked};
      final next = <GroceryLine>[];
      for (final item in (shopping['buy'] as List? ?? []).cast<Map<String, dynamic>>()) {
        next.add(_fromApi(item, meals));
      }
      for (final item in (shopping['already_have'] as List? ?? []).cast<Map<String, dynamic>>()) {
        final line = _fromApi(item, meals);
        line.ticked = true;
        next.add(line);
      }
      for (final line in next) {
        if (ticks.containsKey(line.keyId)) line.ticked = ticks[line.keyId]!;
      }
      lines
        ..clear()
        ..addAll(next)
        ..addAll(manual.where((m) => next.every((n) => n.keyId != m.keyId)));
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => loading = false);
  }

  GroceryLine _fromApi(Map<String, dynamic> item, Map<String, String> meals) {
    final name = item['name'] as String? ?? '';
    final qty = qtyLabel(item['still_needed'] ?? item['quantity'] ?? item['covered'], item['unit'] as String?);
    final keyId = '${normalizeName(name)}|${item['unit'] ?? ''}';
    return GroceryLine(
      keyId: keyId,
      name: name,
      quantity: qty,
      aisle: aisleForName(name),
      meal: meals[normalizeName(name)] ?? 'This week',
    );
  }

  Map<String, String> _mealsByName(Map<String, dynamic>? week) {
    final map = <String, String>{};
    for (final day in (week?['days'] as List? ?? []).cast<Map<String, dynamic>>()) {
      for (final slot in (day['slots'] as List? ?? []).cast<Map<String, dynamic>>()) {
        final recipe = (slot['recipe'] as Map<String, dynamic>?) ?? {};
        final title = recipe['title'] as String? ?? slotLabel('${slot['slot'] ?? ''}');
        final label = '${slotLabel('${slot['slot'] ?? ''}')} · $title';
        final ings = (recipe['scaled_ingredients'] as List? ?? []).cast<Map<String, dynamic>>();
        for (final ing in ings) {
          map.putIfAbsent(normalizeName(ing['name'] as String? ?? ''), () => label);
        }
      }
    }
    return map;
  }

  Future<void> _add() async {
    final added = await showDialog<GroceryLine>(
      context: context,
      builder: (ctx) => const _AddGroceryDialog(),
    );
    if (added == null) return;
    setState(() {
      manual.add(added);
      lines.add(added);
    });
  }

  Future<void> _group() async {
    final next = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text('Group by', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            ListTile(
              title: const Text('Aisle'),
              trailing: groupBy == 'aisle' ? const Icon(Icons.check, color: kGreen) : null,
              onTap: () => Navigator.pop(ctx, 'aisle'),
            ),
            ListTile(
              title: const Text('Meal'),
              trailing: groupBy == 'meal' ? const Icon(Icons.check, color: kGreen) : null,
              onTap: () => Navigator.pop(ctx, 'meal'),
            ),
          ],
        ),
      ),
    );
    if (next == null) return;
    setState(() => groupBy = next);
  }

  Future<void> _share() async {
    final buffer = StringBuffer('Groceries\n');
    final open = lines.where((l) => !l.ticked).toList();
    if (open.isEmpty) buffer.writeln('Nothing left to buy.');
    String? header;
    final grouped = [...open]..sort((a, b) {
        final ah = groupBy == 'meal' ? a.meal : a.aisle;
        final bh = groupBy == 'meal' ? b.meal : b.aisle;
        return ah.compareTo(bh);
      });
    for (final line in grouped) {
      final h = groupBy == 'meal' ? line.meal : line.aisle;
      if (h != header) {
        header = h;
        buffer.writeln('\n$h');
      }
      buffer.writeln('- ${line.name}${line.quantity.isEmpty ? '' : '  ${line.quantity}'}');
    }
    final text = buffer.toString().trim();
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share list', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 12),
            Text(text, style: const TextStyle(height: 1.35)),
            const SizedBox(height: 12),
            const Text('Copied.', style: TextStyle(color: kGreen, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groceries'),
        actions: [
          IconTip(message: 'Group by', onPressed: _group, icon: const Icon(Icons.tune)),
          IconTip(message: 'Share', onPressed: _share, icon: const Icon(Icons.ios_share)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? EmptyHint(text: error!)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: GroceriesList(
                    lines: lines,
                    groupBy: groupBy,
                    onAdd: _add,
                    onToggle: (line, value) => setState(() => line.ticked = value),
                  ),
                ),
    );
  }
}

class GroceriesList extends StatelessWidget {
  const GroceriesList({
    super.key,
    required this.lines,
    required this.groupBy,
    required this.onAdd,
    required this.onToggle,
  });

  final List<GroceryLine> lines;
  final String groupBy;
  final VoidCallback onAdd;
  final void Function(GroceryLine line, bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<GroceryLine>>{};
    for (final line in lines) {
      final key = groupBy == 'meal' ? line.meal : line.aisle;
      groups.putIfAbsent(key, () => []).add(line);
    }
    final headers = groups.keys.toList()..sort();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        AddLine(label: 'Add item', onTap: onAdd),
        if (lines.isEmpty) const EmptyHint(text: 'Nothing to buy.'),
        for (final header in headers) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Text(header, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: kInk)),
          ),
          for (final line in groups[header]!)
            CheckLine(
              title: line.name,
              quantity: line.quantity,
              checked: line.ticked,
              struck: line.ticked,
              onChanged: (v) => onToggle(line, v),
            ),
        ],
      ],
    );
  }
}

class _AddGroceryDialog extends StatefulWidget {
  const _AddGroceryDialog();

  @override
  State<_AddGroceryDialog> createState() => _AddGroceryDialogState();
}

class _AddGroceryDialogState extends State<_AddGroceryDialog> {
  final name = TextEditingController();
  final quantity = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add item'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Item')),
          const SizedBox(height: 8),
          TextField(controller: quantity, decoration: const InputDecoration(labelText: 'Quantity')),
        ],
      ),
      actions: [
        IconTip(
          message: 'Cancel',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: kMuted),
        ),
        FilledButton(
          onPressed: () {
            final trimmed = name.text.trim();
            if (trimmed.isEmpty) return;
            Navigator.pop(
              context,
              GroceryLine(
                keyId: 'manual:${normalizeName(trimmed)}',
                name: trimmed,
                quantity: quantity.text.trim(),
                aisle: aisleForName(trimmed),
                meal: 'Added',
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
