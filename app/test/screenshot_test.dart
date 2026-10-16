import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:week_on_plate/screens/recipes_screen.dart';
import 'package:week_on_plate/screens/shopping_screen.dart';
import 'package:week_on_plate/screens/week_screen.dart';
import 'package:week_on_plate/theme.dart';

const shoot = bool.fromEnvironment('SHOOT');

Future<void> loadInter() async {
  final loader = FontLoader('Inter');
  for (final name in ['Inter-Regular.ttf', 'Inter-SemiBold.ttf', 'Inter-Bold.ttf']) {
    final bytes = File('fonts/$name').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
  }
  await loader.load();
}

Future<void> shootOf(WidgetTester tester, String name) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  final bytes = await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  final dir = Directory('/opt/cursor/artifacts/screenshots');
  dir.createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(bytes!);
}

Widget phone(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: weekOnPlateTheme(),
    home: MediaQuery(
      data: const MediaQueryData(size: Size(390, 844), devicePixelRatio: 2),
      child: RepaintBoundary(key: const Key('shot'), child: child),
    ),
  );
}

void main() {
  testWidgets('write restyle screenshots', (tester) async {
    if (!shoot) return;
    await loadInter();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final days = [
      {
        'date': '2026-09-14',
        'macros': {'kcal': 1950},
        'slots': [
          {
            'slot': 'breakfast',
            'cooked': false,
            'macros': {'kcal': 420},
            'recipe': {'title': 'Overnight oats with berries', 'minutes': 5},
          },
          {
            'slot': 'dinner',
            'cooked': false,
            'macros': {'kcal': 680},
            'recipe': {'title': 'Lemon roast chicken', 'minutes': 55},
          },
        ],
      },
      {
        'date': '2026-09-15',
        'macros': {'kcal': 1620},
        'slots': [
          {
            'slot': 'lunch',
            'cooked': false,
            'macros': {'kcal': 540},
            'recipe': {'title': 'Chickpea and spinach stew', 'minutes': 30},
          },
        ],
      },
      for (var i = 16; i <= 20; i++)
        {'date': '2026-09-$i', 'macros': {'kcal': i == 16 ? 980 : 0}, 'slots': <Map<String, dynamic>>[]},
    ];

    await tester.pumpWidget(
      phone(
        Scaffold(
          appBar: AppBar(title: const Text('This week')),
          body: WeekPage(
            days: days,
            selectedDate: '2026-09-14',
            expanded: {'2026-09-14': true, '2026-09-15': true},
            onSelectDay: (_) {},
            onToggleDay: (_) {},
            onAdd: (_) {},
            onCooked: (_) {},
            onRemove: (_) {},
            onOpen: (_) {},
          ),
        ),
      ),
    );
    await shootOf(tester, 'week');

    await tester.pumpWidget(
      phone(
        Scaffold(
          appBar: AppBar(title: const Text('Recipes')),
          body: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  decoration: InputDecoration(hintText: 'Search', prefixIcon: Icon(Icons.search)),
                ),
              ),
              Expanded(
                child: RecipesGrid(
                  recipes: const [
                    {'title': 'Blueberry pancakes', 'minutes': 30, 'saved': true},
                    {'title': 'Miso salmon traybake', 'minutes': 25, 'saved': false},
                    {'title': 'Lemon roast chicken', 'minutes': 55, 'saved': false},
                    {'title': 'Overnight oats', 'minutes': 5, 'saved': true},
                  ],
                  onOpen: (_) {},
                  onBookmark: (_) {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await shootOf(tester, 'recipes');

    await tester.pumpWidget(
      phone(
        Scaffold(
          appBar: AppBar(title: const Text('Blueberry pancakes')),
          body: RecipePage(
            servings: 3,
            onServings: (_) {},
            recipe: const {
              'title': 'Blueberry pancakes',
              'serves': 2,
              'minutes': 30,
              'method_steps': ['Butter the skillet.', 'Mix the batter and cook until set.'],
              'ingredients': [
                {'name': 'Blueberries', 'quantity': 100, 'unit': 'g'},
                {'name': 'Egg', 'quantity': 1, 'unit': 'each'},
                {'name': 'Rolled oats', 'quantity': 80, 'unit': 'g'},
                {'name': 'Milk', 'quantity': 120, 'unit': 'ml'},
              ],
              'macros': {'kcal': 400, 'protein': 22, 'carbs': 48, 'fat': 11},
            },
          ),
        ),
      ),
    );
    await shootOf(tester, 'recipe');

    final lines = [
      GroceryLine(keyId: '1', name: 'Lemons', quantity: '2', aisle: 'Produce', meal: 'Dinner'),
      GroceryLine(keyId: '2', name: 'Spinach', quantity: '200g', aisle: 'Produce', meal: 'Lunch'),
      GroceryLine(keyId: '3', name: 'Greek yoghurt', quantity: '200g', aisle: 'Dairy & eggs', meal: 'Breakfast'),
      GroceryLine(keyId: '4', name: 'Rolled oats', quantity: '120g', aisle: 'Bakery & grains', meal: 'Breakfast')..ticked = true,
    ];
    await tester.pumpWidget(
      phone(
        Scaffold(
          appBar: AppBar(
            title: const Text('Groceries'),
            actions: const [
              Icon(Icons.tune),
              SizedBox(width: 12),
              Icon(Icons.ios_share),
              SizedBox(width: 12),
            ],
          ),
          body: GroceriesList(lines: lines, groupBy: 'aisle', onAdd: () {}, onToggle: (_, _) {}),
        ),
      ),
    );
    await shootOf(tester, 'groceries');
  });
}
