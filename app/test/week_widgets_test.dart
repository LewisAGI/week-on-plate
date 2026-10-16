import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:week_on_plate/screens/recipes_screen.dart';
import 'package:week_on_plate/screens/shell.dart';
import 'package:week_on_plate/screens/week_screen.dart';
import 'package:week_on_plate/state/session.dart';
import 'package:week_on_plate/theme.dart';
import 'package:week_on_plate/widgets.dart';

void main() {
  testWidgets('fullness grid jumps to a day', (tester) async {
    String selected = '2026-09-14';
    final days = [
      for (var i = 14; i <= 20; i++) {'date': '2026-09-$i', 'slots': <Map<String, dynamic>>[], 'macros': {}},
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: weekOnPlateTheme(),
        home: Scaffold(
          body: WeekFullnessGrid(
            days: days,
            selectedDate: selected,
            onSelect: (d) => selected = d,
          ),
        ),
      ),
    );
    expect(find.text('M'), findsWidgets);
    expect(find.text('S'), findsWidgets);
    await tester.tap(find.text('W'));
    expect(selected, '2026-09-16');
  });

  testWidgets('week list shows a collapsible day and a compact meal card', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var added = '';
    await tester.pumpWidget(
      MaterialApp(
        theme: weekOnPlateTheme(),
        home: Scaffold(
          body: WeekPage(
            days: [
              {
                'date': '2026-09-14',
                'macros': {'kcal': 1950},
                'slots': [
                  {
                    'id': 'slt_1',
                    'slot': 'dinner',
                    'cooked': false,
                    'macros': {'kcal': 520, 'protein': 40, 'carbs': 30, 'fat': 20},
                    'recipe': {
                      'id': 'rcp_1',
                      'title': 'Lemon roast chicken and potatoes',
                      'minutes': 55,
                    },
                  },
                ],
              },
            ],
            selectedDate: '2026-09-14',
            expanded: {'2026-09-14': true},
            onSelectDay: (_) {},
            onToggleDay: (_) {},
            onAdd: (date) => added = date,
            onCooked: (_) {},
            onRemove: (_) {},
            onOpen: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Mon · 1,950 kcal'), findsOneWidget);
    expect(find.text('Lemon roast chicken and potatoes'), findsOneWidget);
    expect(find.text('55 min'), findsOneWidget);
    expect(find.text('520 kcal'), findsOneWidget);
    expect(find.text('Dinner'), findsOneWidget);
    expect(find.text('Ingredients'), findsNothing);
    await tester.tap(find.byTooltip('Add a meal'));
    expect(added, '2026-09-14');
  });

  testWidgets('recipe picker filters the list', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: weekOnPlateTheme(),
        home: Scaffold(
          body: RecipePickerSheet(
            recipes: [
              {'id': 'a', 'title': 'Lemon chicken', 'minutes': 55, 'serves': 4},
              {'id': 'b', 'title': 'Overnight oats', 'minutes': 5, 'serves': 2},
            ],
          ),
        ),
      ),
    );
    expect(find.text('Lemon chicken'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'oat');
    await tester.pump();
    expect(find.text('Lemon chicken'), findsNothing);
    expect(find.text('Overnight oats'), findsOneWidget);
  });

  testWidgets('new recipe form adds a step from the icon', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = Session();
    await tester.pumpWidget(
      MaterialApp(
        theme: weekOnPlateTheme(),
        home: RecipeEditScreen(session: session),
      ),
    );
    expect(find.byTooltip('Add step'), findsOneWidget);
    expect(find.byTooltip('Add ingredient'), findsOneWidget);
    expect(find.text('Step 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Add step'));
    await tester.pump();
    expect(find.text('Step 2'), findsOneWidget);
  });

  testWidgets('bottom nav says Groceries not Shop', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: weekOnPlateTheme(),
        home: AppShell(session: Session()),
      ),
    );
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Shop'), findsNothing);
  });
}
