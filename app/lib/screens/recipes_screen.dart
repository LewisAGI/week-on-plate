import 'package:flutter/material.dart';

import '../api/api.dart';
import '../state/session.dart';
import '../theme.dart';
import '../widgets.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key, required this.session});
  final Session session;

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  String scope = 'browse';
  List<Map<String, dynamic>> recipes = [];
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
      final data = await api.recipes(scope: scope);
      recipes = (data['recipes'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _open(Map<String, dynamic> recipe) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecipeDetailScreen(session: widget.session, recipeId: recipe['id'] as String),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recipes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => RecipeEditScreen(session: widget.session),
            ),
          );
          await _load();
        },
        label: const Text('New recipe'),
        icon: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(
              spacing: 8,
              children: [
                for (final s in [
                  ('browse', 'Browse'),
                  ('saved', 'Saved'),
                  ('mine', 'Mine'),
                  ('house', 'House'),
                ])
                  ChoiceChip(
                    label: Text(s.$2),
                    selected: scope == s.$1,
                    onSelected: (_) {
                      setState(() => scope = s.$1);
                      _load();
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? EmptyHint(text: error!)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: recipes.length,
                        itemBuilder: (context, i) {
                          final r = recipes[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              title: Text(r['title'] as String),
                              subtitle: Text(
                                [
                                  if (r['house_recipe'] == true) 'House recipe',
                                  if (r['exclusive'] == true) 'Pack',
                                  'Serves ${r['serves']}',
                                ].join(' · '),
                              ),
                              onTap: () => _open(r),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({super.key, required this.session, required this.recipeId});
  final Session session;
  final String recipeId;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  Map<String, dynamic>? recipe;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.session.api.recipe(widget.recipeId);
      recipe = data['recipe'] as Map<String, dynamic>?;
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() {});
  }

  Future<void> _addToWeek() async {
    final now = DateTime.now().toUtc();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day - 1),
      lastDate: now.add(const Duration(days: 21)),
      initialDate: now,
    );
    if (date == null || !mounted) return;
    final slot = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in ['breakfast', 'lunch', 'dinner', 'snack'])
              ListTile(title: Text(s), onTap: () => Navigator.pop(ctx, s)),
          ],
        ),
      ),
    );
    if (slot == null) return;
    final y = date.toIso8601String().sliceDate;
    await widget.session.api.addToWeek(date: y, slot: slot, recipeId: widget.recipeId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to the week.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = recipe;
    return Scaffold(
      appBar: AppBar(title: Text(r?['title'] as String? ?? 'Recipe')),
      body: r == null
          ? Center(child: error == null ? const CircularProgressIndicator() : Text(error!))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if ((r['summary'] as String?)?.isNotEmpty == true)
                  Text(r['summary'] as String, style: const TextStyle(color: kMuted)),
                const SizedBox(height: 8),
                Text('Serves ${r['serves']} · scaled to your household', style: const TextStyle(color: kGreenDark)),
                const SizedBox(height: 12),
                MacrosRow(macros: (r['scaled_macros'] as Map<String, dynamic>?) ?? {}),
                const SizedBox(height: 16),
                const Text('Ingredients', style: TextStyle(fontWeight: FontWeight.w700, color: kGreen)),
                for (final ing in (r['scaled_ingredients'] as List? ?? []))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${qtyLabel(ing['quantity'], ing['unit'] as String?)} ${ing['name']}'.trim(),
                    ),
                  ),
                const SizedBox(height: 8),
                const Text('Method', style: TextStyle(fontWeight: FontWeight.w700, color: kGreen)),
                Text(r['method'] as String? ?? ''),
                const SizedBox(height: 20),
                FilledButton(onPressed: _addToWeek, child: const Text('Add to this week')),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    if (r['saved'] == true) {
                      await widget.session.api.unsaveRecipe(widget.recipeId);
                    } else {
                      await widget.session.api.saveRecipe(widget.recipeId);
                    }
                    await _load();
                  },
                  child: Text(r['saved'] == true ? 'Remove from saved' : 'Save recipe'),
                ),
                if (r['mine'] == true)
                  TextButton(
                    onPressed: () async {
                      await widget.session.api.publishRecipe(widget.recipeId);
                      await _load();
                    },
                    child: const Text('Publish'),
                  ),
              ],
            ),
    );
  }
}

extension on String {
  String get sliceDate => length >= 10 ? substring(0, 10) : this;
}

class RecipeEditScreen extends StatefulWidget {
  const RecipeEditScreen({super.key, required this.session});
  final Session session;

  @override
  State<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends State<RecipeEditScreen> {
  final title = TextEditingController();
  final summary = TextEditingController();
  final method = TextEditingController();
  final serves = TextEditingController(text: '2');
  final ingredients = TextEditingController(
    text: '400g chicken breast\n200g rice\n1 tbsp olive oil',
  );
  bool publish = true;
  bool exclusive = false;
  bool busy = false;

  @override
  void dispose() {
    title.dispose();
    summary.dispose();
    method.dispose();
    serves.dispose();
    ingredients.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _parseIngs() {
    final out = <Map<String, dynamic>>[];
    final re = RegExp(
      r'^\s*(\d+(?:\.\d+)?)\s*(kg|g|ml|l|tbsp|tsp|x)?\s+(.+)$',
      caseSensitive: false,
    );
    for (final line in ingredients.text.split('\n')) {
      final m = re.firstMatch(line.trim());
      if (m != null) {
        out.add({
          'name': m.group(3),
          'quantity': num.parse(m.group(1)!),
          'unit': (m.group(2) ?? 'each').toLowerCase(),
        });
      } else if (line.trim().isNotEmpty) {
        out.add({'name': line.trim(), 'quantity': null, 'unit': 'each'});
      }
    }
    return out;
  }

  Future<void> _save() async {
    setState(() => busy = true);
    try {
      await widget.session.api.createRecipe({
        'title': title.text.trim(),
        'summary': summary.text.trim(),
        'method': method.text.trim(),
        'serves': int.tryParse(serves.text) ?? 2,
        'published': publish,
        'exclusive': exclusive,
        'ingredients': _parseIngs(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showMessage(context, e.toString());
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New recipe')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 8),
          TextField(controller: summary, decoration: const InputDecoration(labelText: 'Summary')),
          const SizedBox(height: 8),
          TextField(controller: serves, decoration: const InputDecoration(labelText: 'Serves'), keyboardType: TextInputType.number),
          const SizedBox(height: 8),
          TextField(
            controller: ingredients,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(labelText: 'Ingredients (one per line, e.g. 400g chicken breast)'),
          ),
          const SizedBox(height: 8),
          TextField(controller: method, minLines: 4, maxLines: 8, decoration: const InputDecoration(labelText: 'Method')),
          SwitchListTile(
            title: const Text('Publish so others can browse it'),
            value: publish,
            onChanged: (v) => setState(() => publish = v),
          ),
          SwitchListTile(
            title: const Text('Exclusive to a pack'),
            value: exclusive,
            onChanged: (v) => setState(() => exclusive = v),
          ),
          FilledButton(onPressed: busy ? null : _save, child: const Text('Save recipe')),
        ],
      ),
    );
  }
}
