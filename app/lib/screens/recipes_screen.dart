import 'package:flutter/material.dart';

import '../domain/method.dart';
import '../state/session.dart';
import '../theme.dart';
import '../widgets.dart';

const recipeScopes = [
  ('browse', 'Browse'),
  ('saved', 'Saved'),
  ('mine', 'Mine'),
  ('house', 'House'),
];

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key, required this.session});
  final Session session;

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  String scope = 'browse';
  String query = '';
  List<Map<String, dynamic>> recipes = [];
  String? error;
  bool loading = true;

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
      final data = await widget.session.api.recipes(scope: scope);
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

  Future<void> _filter() async {
    final next = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text('Show', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            for (final s in recipeScopes)
              ListTile(
                title: Text(s.$2),
                trailing: scope == s.$1 ? const Icon(Icons.check, color: kGreen) : null,
                onTap: () => Navigator.pop(ctx, s.$1),
              ),
          ],
        ),
      ),
    );
    if (next == null || next == scope) return;
    setState(() => scope = next);
    await _load();
  }

  Future<void> _toggleSave(Map<String, dynamic> recipe) async {
    final id = recipe['id'] as String;
    if (recipe['saved'] == true) {
      await widget.session.api.unsaveRecipe(id);
    } else {
      await widget.session.api.saveRecipe(id);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = recipes.where((r) {
      final title = (r['title'] as String? ?? '').toLowerCase();
      return query.trim().isEmpty || title.contains(query.trim().toLowerCase());
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Recipes')),
      floatingActionButton: Tooltip(
        message: 'New recipe',
        triggerMode: TooltipTriggerMode.longPress,
        child: FloatingActionButton(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => RecipeEditScreen(session: widget.session)),
            );
            await _load();
          },
          child: const Icon(Icons.add),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => query = v),
                  ),
                ),
                IconTip(message: 'Filter', onPressed: _filter, icon: const Icon(Icons.tune)),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? EmptyHint(text: error!)
                    : RecipesGrid(
                        recipes: filtered,
                        onOpen: _open,
                        onBookmark: _toggleSave,
                      ),
          ),
        ],
      ),
    );
  }
}

class RecipesGrid extends StatelessWidget {
  const RecipesGrid({
    super.key,
    required this.recipes,
    required this.onOpen,
    required this.onBookmark,
  });

  final List<Map<String, dynamic>> recipes;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final ValueChanged<Map<String, dynamic>> onBookmark;

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) return const EmptyHint(text: 'No recipes yet.');
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: recipes.length,
      itemBuilder: (context, i) => RecipeGridCard(
        recipe: recipes[i],
        onTap: () => onOpen(recipes[i]),
        onBookmark: () => onBookmark(recipes[i]),
      ),
    );
  }
}

class RecipeGridCard extends StatelessWidget {
  const RecipeGridCard({
    super.key,
    required this.recipe,
    required this.onTap,
    required this.onBookmark,
  });

  final Map<String, dynamic> recipe;
  final VoidCallback onTap;
  final VoidCallback onBookmark;

  @override
  Widget build(BuildContext context) {
    final title = recipe['title'] as String? ?? 'Recipe';
    final saved = recipe['saved'] == true;
    final minutes = recipe['minutes'];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                FoodThumb(seed: title, borderRadius: 16),
                if (minutes != null)
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: kInk.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$minutes min',
                        style: const TextStyle(color: kWhite, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Tooltip(
                    message: saved ? 'Remove bookmark' : 'Bookmark',
                    triggerMode: TooltipTriggerMode.longPress,
                    child: IconButton(
                      onPressed: onBookmark,
                      icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border, color: kWhite),
                      style: IconButton.styleFrom(backgroundColor: kGreen.withValues(alpha: 0.85)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: kInk),
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
  int? servings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.session.api.recipe(widget.recipeId);
      recipe = data['recipe'] as Map<String, dynamic>?;
      servings ??= (recipe?['serves'] as num?)?.round() ?? 2;
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
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const SlotPickerSheet(),
    );
    if (slot == null) return;
    final y = date.toIso8601String().sliceDate;
    await widget.session.api.addToWeek(date: y, slot: slot, recipeId: widget.recipeId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to the week.')));
    }
  }

  Future<void> _toggleSave() async {
    final r = recipe;
    if (r == null) return;
    if (r['saved'] == true) {
      await widget.session.api.unsaveRecipe(widget.recipeId);
    } else {
      await widget.session.api.saveRecipe(widget.recipeId);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final r = recipe;
    return Scaffold(
      appBar: AppBar(
        title: Text(r?['title'] as String? ?? 'Recipe'),
        actions: [
          if (r != null) ...[
            IconTip(
              message: r['saved'] == true ? 'Remove bookmark' : 'Bookmark',
              onPressed: _toggleSave,
              icon: Icon(r['saved'] == true ? Icons.bookmark : Icons.bookmark_border),
            ),
            IconTip(
              message: 'Add to this week',
              onPressed: _addToWeek,
              icon: const Icon(Icons.calendar_month_outlined),
            ),
            PopupMenuButton<String>(
              tooltip: 'More',
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                if (value == 'edit') {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RecipeEditScreen(session: widget.session, recipe: r),
                    ),
                  );
                  await _load();
                }
                if (value == 'publish') {
                  await widget.session.api.publishRecipe(widget.recipeId);
                  await _load();
                }
              },
              itemBuilder: (context) => [
                if (r['mine'] == true) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (r['mine'] == true) const PopupMenuItem(value: 'publish', child: Text('Publish')),
              ],
            ),
          ],
        ],
      ),
      body: r == null
          ? Center(child: error == null ? const CircularProgressIndicator() : Text(error!))
          : RecipePage(
              recipe: r,
              servings: servings ?? (r['serves'] as num?)?.round() ?? 2,
              onServings: (v) => setState(() => servings = v),
            ),
    );
  }
}

class RecipePage extends StatelessWidget {
  const RecipePage({
    super.key,
    required this.recipe,
    required this.servings,
    required this.onServings,
  });

  final Map<String, dynamic> recipe;
  final int servings;
  final ValueChanged<int> onServings;

  @override
  Widget build(BuildContext context) {
    final title = recipe['title'] as String? ?? 'Recipe';
    final minutes = recipe['minutes'];
    final steps = stepsFromRecipe(recipe);
    final ingredients = scaledIngredients(recipe, servings);
    final macros = scaledMacros(recipe, servings);
    final meta = [
      if (minutes != null) '$minutes min',
      '${steps.length} ${steps.length == 1 ? 'step' : 'steps'}',
      if (recipe['house_recipe'] == true) 'House',
      if (recipe['exclusive'] == true) 'Pack',
    ].join(' · ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: FoodThumb(seed: title, borderRadius: 18),
        ),
        const SizedBox(height: 14),
        Text(meta, style: const TextStyle(color: kMuted, fontSize: 14)),
        const SizedBox(height: 8),
        ServingsStepper(value: servings, onChanged: onServings),
        const SizedBox(height: 12),
        MacroCard(macros: macros),
        const SizedBox(height: 20),
        const Text('Ingredients', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: kInk)),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 72,
            crossAxisSpacing: 12,
            mainAxisSpacing: 8,
          ),
          itemCount: ingredients.length,
          itemBuilder: (context, i) {
            final ing = ingredients[i];
            final name = ing['name'] as String? ?? '';
            return Row(
              children: [
                const Icon(Icons.circle, size: 8, color: kGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        qtyLabel(ing['quantity'], ing['unit'] as String?),
                        style: const TextStyle(color: kGreen, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        const Text('Steps', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: kInk)),
        const SizedBox(height: 12),
        MethodStepsList(steps: steps),
      ],
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

  List<String> _collectSteps() => steps.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();

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
          TextField(
            controller: serves,
            decoration: const InputDecoration(labelText: 'Serves'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text('Ingredients', style: TextStyle(fontWeight: FontWeight.w700, color: kGreen, fontSize: 16)),
              ),
              IconTip(
                message: 'Add ingredient',
                onPressed: () => setState(() => ingredients.add(_IngredientDraft())),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
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
                        IconTip(
                          message: 'Remove ingredient',
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
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text('Method', style: TextStyle(fontWeight: FontWeight.w700, color: kGreen, fontSize: 16)),
              ),
              IconTip(
                message: 'Add step',
                onPressed: () => setState(() => steps.add(TextEditingController())),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
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
                  IconTip(
                    message: 'Remove step',
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
