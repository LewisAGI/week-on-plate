import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:week_on_plate/screens/recipes_screen.dart';
import 'package:week_on_plate/screens/shopping_screen.dart';
import 'package:week_on_plate/theme.dart';
import 'package:week_on_plate/widgets.dart';

void main() {
  testWidgets('recipe grid shows a time overlay and a bookmark', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var bookmarks = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: weekOnPlateTheme(),
        home: Scaffold(
          body: RecipesGrid(
            recipes: [
              {'id': '1', 'title': 'Blueberry pancakes', 'minutes': 30, 'saved': false},
              {'id': '2', 'title': 'Miso salmon', 'minutes': 25, 'saved': true},
            ],
            onOpen: (_) {},
            onBookmark: (_) => bookmarks++,
          ),
        ),
      ),
    );
    expect(find.text('30 min'), findsOneWidget);
    expect(find.text('Blueberry pancakes'), findsOneWidget);
    expect(find.byTooltip('Bookmark'), findsOneWidget);
    await tester.tap(find.byTooltip('Bookmark'));
    expect(bookmarks, 1);
  });

  testWidgets('recipe page steps servings and lays out ingredients in two columns', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var servings = 2;
    await tester.pumpWidget(
      MaterialApp(
        theme: weekOnPlateTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => RecipePage(
              servings: servings,
              onServings: (v) => setState(() => servings = v),
              recipe: {
                'title': 'Blueberry pancakes',
                'serves': 2,
                'minutes': 30,
                'method_steps': ['Butter the skillet.', 'Mix the batter.'],
                'ingredients': [
                  {'name': 'Blueberries', 'quantity': 100, 'unit': 'g'},
                  {'name': 'Egg', 'quantity': 1, 'unit': 'each'},
                ],
                'macros': {'kcal': 400, 'protein': 20, 'carbs': 40, 'fat': 12},
              },
            ),
          ),
        ),
      ),
    );
    expect(find.text('30 min · 2 steps'), findsOneWidget);
    expect(find.text('Blueberries'), findsOneWidget);
    expect(find.text('Egg'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(find.text('2'), findsWidgets);
    expect(find.text('Butter the skillet.'), findsOneWidget);
    await tester.tap(find.byTooltip('More servings'));
    await tester.pump();
    expect(servings, 3);
    expect(find.text('150g'), findsOneWidget);
  });

  testWidgets('groceries group by aisle and strike ticked rows in place', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final lemons = GroceryLine(keyId: 'lemons', name: 'Lemons', quantity: '2', aisle: 'Produce', meal: 'Dinner · Chicken');
    final oats = GroceryLine(keyId: 'oats', name: 'Rolled oats', quantity: '120g', aisle: 'Bakery & grains', meal: 'Breakfast · Oats');
    await tester.pumpWidget(
      MaterialApp(
        theme: weekOnPlateTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => GroceriesList(
              lines: [lemons, oats],
              groupBy: 'aisle',
              onAdd: () {},
              onToggle: (line, value) => setState(() => line.ticked = value),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Produce'), findsOneWidget);
    expect(find.text('Bakery & grains'), findsOneWidget);
    expect(find.text('Add item'), findsOneWidget);
    final before = tester.widget<Text>(find.text('Lemons'));
    expect(before.style?.decoration, isNot(TextDecoration.lineThrough));
    await tester.tap(find.text('Lemons'));
    await tester.pump();
    final after = tester.widget<Text>(find.text('Lemons'));
    expect(after.style?.decoration, TextDecoration.lineThrough);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('filter pop-out replaces scope chips', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: weekOnPlateTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: IconTip(
              message: 'Filter',
              icon: const Icon(Icons.tune),
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  builder: (ctx) => const SafeArea(child: Text('Saved')),
                );
              },
            ),
          ),
        ),
      ),
    );
    expect(find.byType(ChoiceChip), findsNothing);
    await tester.tap(find.byTooltip('Filter'));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
  });
}
