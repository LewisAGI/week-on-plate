import 'package:flutter/material.dart';

import '../domain/scale.dart';
import '../state/session.dart';
import '../theme.dart';
import '../widgets.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    final user = session.user ?? {};
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(user['display_name'] as String? ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kGreenDark)),
          Text(user['email'] as String? ?? '', style: const TextStyle(color: kMuted)),
          Text(
            session.isCreator ? 'Role: creator' : 'Role: buyer',
            style: const TextStyle(color: kMuted),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Household'),
            subtitle: const Text('Adults and under-18s'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => HouseholdScreen(session: session))),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Import a reel or caption'),
            subtitle: const Text('Paste text, then confirm'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ImportScreen(session: session))),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Creator packs'),
            subtitle: const Text('Demonstration checkout — no card is taken'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => PacksScreen(session: session))),
          ),
          const SizedBox(height: 12),
          Text('API: ${session.api.base}', style: const TextStyle(color: kMuted, fontSize: 12)),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: session.logout, child: const Text('Sign out')),
        ],
      ),
    );
  }
}

class HouseholdScreen extends StatefulWidget {
  const HouseholdScreen({super.key, required this.session});
  final Session session;

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  int adults = 2;
  int under18s = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await widget.session.api.household();
    final h = data['household'] as Map<String, dynamic>;
    setState(() {
      adults = (h['adults'] as num).toInt();
      under18s = (h['under18s'] as num).toInt();
      loading = false;
    });
  }

  Future<void> _save() async {
    await widget.session.api.saveHousehold(adults, under18s);
    await widget.session.refreshUser();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Household saved.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Household')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Recipes scale to the number of people at the table. The default is two adults.',
                  style: TextStyle(color: kMuted, height: 1.4),
                ),
                const SizedBox(height: 16),
                Text('Adults: $adults', style: const TextStyle(fontWeight: FontWeight.w700, color: kGreen)),
                Slider(
                  min: 1,
                  max: 8,
                  divisions: 7,
                  value: adults.toDouble(),
                  onChanged: (v) => setState(() => adults = v.round()),
                ),
                Text('Under-18s: $under18s', style: const TextStyle(fontWeight: FontWeight.w700, color: kGreen)),
                Slider(
                  min: 0,
                  max: 8,
                  divisions: 8,
                  value: under18s.toDouble(),
                  onChanged: (v) => setState(() => under18s = v.round()),
                ),
                const SizedBox(height: 8),
                Text(teenTip, style: const TextStyle(color: kMuted, height: 1.4)),
                const SizedBox(height: 20),
                FilledButton(onPressed: _save, child: const Text('Save household')),
              ],
            ),
    );
  }
}

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key, required this.session});
  final Session session;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final text = TextEditingController(
    text: '''High-protein chicken bowl
Serves 2
https://www.instagram.com/reel/example

Ingredients:
- 400g chicken breast
- 200g rice
- 1 tbsp olive oil
- 150g spinach

Method:
1. Cook the rice.
2. Fry the chicken.
3. Wilt the spinach and plate up.''',
  );
  bool busy = false;

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> _extract() async {
    setState(() => busy = true);
    try {
      final data = await widget.session.api.extractImport(text.text);
      final draft = data['draft'] as Map<String, dynamic>;
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ImportConfirmScreen(session: widget.session, draft: draft),
        ),
      );
    } catch (e) {
      if (mounted) showMessage(context, e.toString());
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Paste a caption, a link plus the text around it, or the recipe itself. We extract a draft. You confirm before anything is saved. Screenshot OCR is not in this MVP.',
            style: TextStyle(color: kMuted, height: 1.4),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: text,
            minLines: 10,
            maxLines: 16,
            decoration: const InputDecoration(labelText: 'Caption or link text'),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: busy ? null : _extract, child: Text(busy ? 'Reading…' : 'Extract draft')),
        ],
      ),
    );
  }
}

class ImportConfirmScreen extends StatefulWidget {
  const ImportConfirmScreen({super.key, required this.session, required this.draft});
  final Session session;
  final Map<String, dynamic> draft;

  @override
  State<ImportConfirmScreen> createState() => _ImportConfirmScreenState();
}

class _ImportConfirmScreenState extends State<ImportConfirmScreen> {
  late final title = TextEditingController(text: widget.draft['title'] as String? ?? '');
  late final serves = TextEditingController(text: '${widget.draft['serves'] ?? 2}');
  late final method = TextEditingController(text: widget.draft['method'] as String? ?? '');
  late final ingredients = TextEditingController(
    text: ((widget.draft['ingredients'] as List?) ?? [])
        .map((ing) => '${qtyLabel(ing['quantity'], ing['unit'] as String?)} ${ing['name']}'.trim())
        .join('\n'),
  );
  bool busy = false;

  @override
  void dispose() {
    title.dispose();
    serves.dispose();
    method.dispose();
    ingredients.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() => busy = true);
    try {
      final ings = <Map<String, dynamic>>[];
      final re = RegExp(r'^\s*(\d+(?:\.\d+)?)(kg|g|ml|l|tbsp|tsp)?\s+(.+)$', caseSensitive: false);
      for (final line in ingredients.text.split('\n')) {
        final m = re.firstMatch(line.trim());
        if (m != null) {
          ings.add({
            'quantity': num.parse(m.group(1)!),
            'unit': (m.group(2) ?? 'each').toLowerCase(),
            'name': m.group(3),
          });
        }
      }
      await widget.session.api.confirmImport({
        ...widget.draft,
        'title': title.text.trim(),
        'serves': int.tryParse(serves.text) ?? 2,
        'method': method.text,
        'ingredients': ings,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recipe saved. Confirm step done.')));
        Navigator.pop(context);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString());
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm import')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Extractor: ${widget.draft['extractor'] ?? 'heuristic'}', style: const TextStyle(color: kMuted)),
          const SizedBox(height: 8),
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 8),
          TextField(controller: serves, decoration: const InputDecoration(labelText: 'Serves'), keyboardType: TextInputType.number),
          const SizedBox(height: 8),
          TextField(controller: ingredients, minLines: 4, maxLines: 8, decoration: const InputDecoration(labelText: 'Ingredients')),
          const SizedBox(height: 8),
          TextField(controller: method, minLines: 4, maxLines: 8, decoration: const InputDecoration(labelText: 'Method')),
          const SizedBox(height: 16),
          FilledButton(onPressed: busy ? null : _confirm, child: const Text('Looks right — save')),
        ],
      ),
    );
  }
}

class PacksScreen extends StatefulWidget {
  const PacksScreen({super.key, required this.session});
  final Session session;

  @override
  State<PacksScreen> createState() => _PacksScreenState();
}

class _PacksScreenState extends State<PacksScreen> {
  List<Map<String, dynamic>> packs = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await widget.session.api.packs();
    setState(() {
      packs = (data['packs'] as List? ?? []).cast<Map<String, dynamic>>();
      loading = false;
    });
  }

  Future<void> _buy(Map<String, dynamic> pack) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Demonstration checkout'),
        content: Text(
          'Buy “${pack['title']}” for ${money(pack['price_pence'] as int)}? No card is taken. Equity and payouts are not in this MVP.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Stub-buy')),
        ],
      ),
    );
    if (ok != true) return;
    final result = await widget.session.api.purchasePack(pack['id'] as String);
    if (mounted) {
      await showMessage(context, result['message'] as String? ?? 'Purchased.');
      await _load();
    }
  }

  Future<void> _create() async {
    final mine = await widget.session.api.recipes(scope: 'mine');
    final recipes = (mine['recipes'] as List? ?? []).cast<Map<String, dynamic>>();
    if (!mounted) return;
    final selected = <String>{};
    final title = TextEditingController();
    final price = TextEditingController(text: '900');
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('New pack'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: title, decoration: const InputDecoration(labelText: 'Pack title')),
                  TextField(controller: price, decoration: const InputDecoration(labelText: 'Price (pence)'), keyboardType: TextInputType.number),
                  const SizedBox(height: 8),
                  for (final r in recipes)
                    CheckboxListTile(
                      title: Text(r['title'] as String),
                      value: selected.contains(r['id']),
                      onChanged: (v) => setLocal(() {
                        if (v == true) {
                          selected.add(r['id'] as String);
                        } else {
                          selected.remove(r['id']);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                await widget.session.api.createPack({
                  'title': title.text.trim(),
                  'summary': 'A demonstration pack',
                  'price_pence': int.tryParse(price.text) ?? 0,
                  'recipe_ids': selected.toList(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Publish pack'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    price.dispose();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Creator packs'),
        actions: [
          if (widget.session.isCreator) IconButton(onPressed: _create, icon: const Icon(Icons.add)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final pack in packs)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(pack['title'] as String),
                      subtitle: Text('${pack['summary']}\n${money(pack['price_pence'] as int)}'),
                      isThreeLine: true,
                      trailing: pack['purchased'] == true
                          ? const Text('Yours', style: TextStyle(color: kGreen, fontWeight: FontWeight.w700))
                          : FilledButton(onPressed: () => _buy(pack), child: const Text('Buy')),
                    ),
                  ),
              ],
            ),
    );
  }
}
