import 'package:flutter/material.dart';

import '../api/api.dart';
import '../domain/method.dart';
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
      appBar: AppBar(
        title: Text(r?['title'] as String? ?? 'Recipe'),
        actions: [
          if (r?['mine'] == true)
            IconButton(
              tooltip: 'Edit',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RecipeEditScreen(session: widget.session, recipe: r),
                  ),
                );
                await _load();
              },
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
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
                const SizedBox(height: 8),
                MethodStepsList.fromRecipe(r),
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

const ingredientUnits = ['g', 'kg', 'ml', 'l', 'tbsp', 'tsp', 'each'];

class _IngredientDraft {
  _IngredientDraft({String name = '', String quantity = '', this.unit = 'g'})
      : name = TextEditingController(text: name),
        quantity = TextEditingController(text: quantity);

  final TextEditingController name;
  final TextEditingController quantity;
  String unit;

  void dispose() {
    name.dispose();
    quantity.dispose();
  }
}

class RecipeEditScreen extends StatefulWidget {
  const RecipeEditScreen({super.key, required this.session, this.recipe});
  final Session session;
  final Map<String, dynamic>? recipe;

  @override
  State<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends State<RecipeEditScreen> {
  late final title = TextEditingController(text: widget.recipe?['title'] as String? ?? '');
  late final summary = TextEditingController(text: widget.recipe?['summary'] as String? ?? '');
  late final serves = TextEditingController(text: '${widget.recipe?['serves'] ?? 2}');
  late final ingredients = <_IngredientDraft>[];
  late final steps = <TextEditingController>[];
  late bool publish = widget.recipe?['published'] != false;
  late bool exclusive = widget.recipe?['exclusive'] == true;
  bool busy = false;

  bool get editing => widget.recipe?['id'] != null;

  @override
  void initState() {
    super.initState();
    final existingIngs = (widget.recipe?['ingredients'] as List? ?? []).cast<Map<String, dynamic>>();
    if (existingIngs.isEmpty) {
      ingredients.add(_IngredientDraft());
    } else {
      for (final ing in existingIngs) {
        final qty = ing['quantity'];
        ingredients.add(_IngredientDraft(
          name: ing['name'] as String? ?? '',
          quantity: qty == null ? '' : '$qty',
          unit: (ing['unit'] as String?)?.isNotEmpty == true ? ing['unit'] as String : 'g',
        ));
      }
    }
    final existingSteps = stepsFromRecipe(widget.recipe ?? {});
    if (existingSteps.isEmpty) {
      steps.add(TextEditingController());
    } else {
      for (final step in existingSteps) {
        steps.add(TextEditingController(text: step));
      }
    }
  }

  @override
  void dispose() {
    title.dispose();
    summary.dispose();
    serves.dispose();
    for (final ing in ingredients) {
      ing.dispose();
    }
    for (final step in steps) {
      step.dispose();
    }
    super.dispose();
  }

  List<Map<String, dynamic>> _collectIngredients() {
    final out = <Map<String, dynamic>>[];
    for (final ing in ingredients) {
      final name = ing.name.text.trim();
      if (name.isEmpty) continue;
      final qty = num.tryParse(ing.quantity.text.trim());
      out.add({'name': name, 'quantity': qty, 'unit': ing.unit});
    }
    return out;
  }

  List<String> _collectSteps() =>
      steps.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();

  Future<void> _save() async {
    setState(() => busy = true);
    try {
      final methodSteps = _collectSteps();
      final body = {
        'title': title.text.trim(),
        'summary': summary.text.trim(),
        'method': methodSteps.join('\n'),
        'method_steps': methodSteps,
        'serves': int.tryParse(serves.text) ?? 2,
        'published': publish,
        'exclusive': exclusive,
        'ingredients': _collectIngredients(),
      };
      if (editing) {
        await widget.session.api.updateRecipe(widget.recipe!['id'] as String, body);
      } else {
        await widget.session.api.createRecipe(body);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showMessage(context, e.toString());
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit recipe' : 'New recipe')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 8),
          TextField(controller: summary, decoration: const InputDecoration(labelText: 'Summary')),
          const SizedBox(height: 8),
          TextField(controller: serves, decoration: const InputDecoration(labelText: 'Serves'), keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          const Text('Ingredients', style: TextStyle(fontWeight: FontWeight.w700, color: kGreen, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('One field per ingredient — not a blob of text.', style: TextStyle(color: kMuted)),
          const SizedBox(height: 8),
          for (var i = 0; i < ingredients.length; i++)
            Card(
              key: ObjectKey(ingredients[i]),
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: ingredients[i].name,
                            decoration: const InputDecoration(labelText: 'Ingredient'),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove ingredient',
                          onPressed: ingredients.length <= 1
                              ? null
                              : () => setState(() {
                                    final removed = ingredients.removeAt(i);
                                    removed.dispose();
                                  }),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: ingredients[i].quantity,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Quantity'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: ingredientUnits.contains(ingredients[i].unit) ? ingredients[i].unit : 'each',
                            items: [
                              for (final u in ingredientUnits) DropdownMenuItem(value: u, child: Text(u)),
                            ],
                            onChanged: (v) => setState(() => ingredients[i].unit = v ?? 'g'),
                            decoration: const InputDecoration(labelText: 'Unit'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => ingredients.add(_IngredientDraft())),
              icon: const Icon(Icons.add),
              label: const Text('Add ingredient'),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Method', style: TextStyle(fontWeight: FontWeight.w700, color: kGreen, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('One step per line. We keep them numbered.', style: TextStyle(color: kMuted)),
          const SizedBox(height: 8),
          for (var i = 0; i < steps.length; i++)
            Padding(
              key: ObjectKey(steps[i]),
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text('${i + 1}.', style: const TextStyle(fontWeight: FontWeight.w700, color: kGreen)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: steps[i],
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(labelText: 'Step ${i + 1}'),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove step',
                    onPressed: steps.length <= 1
                        ? null
                        : () => setState(() {
                              final removed = steps.removeAt(i);
                              removed.dispose();
                            }),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => steps.add(TextEditingController())),
              icon: const Icon(Icons.add),
              label: const Text('Add step'),
            ),
          ),
          SwitchListTile(
            title: const Text('Publish so others can browse it'),
            value: publish,
            onChanged: (v) => setState(() => publish = v),
          ),
          if (widget.session.isCreator)
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
