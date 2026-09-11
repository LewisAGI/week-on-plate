import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:week_on_plate/screens/recipes_screen.dart';
import 'package:week_on_plate/screens/shell.dart';
import 'package:week_on_plate/screens/week_screen.dart';
import 'package:week_on_plate/state/session.dart';
import 'package:week_on_plate/theme.dart';
import 'package:week_on_plate/widgets.dart';

void main() {
  testWidgets('day strip selects Monday through Sunday', (tester) async {
    String selected = '2026-09-14';
    final days = [
      for (var i = 14; i <= 20; i++) {'date': '2026-09-$i', 'slots': [], 'macros': {}},
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: weekOnPlateTheme(),
        home: Scaffold(
          body: WeekDayStrip(
            days: days,
            selectedDate: selected,
            onSelect: (d) => selected = d,
          ),
        ),
      ),
    );
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Sun'), findsOneWidget);
    await tester.tap(find.text('Wed'));
    expect(selected, '2026-09-16');
  });

  testWidgets('meal card shows name, bits, macros and method steps', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: weekOnPlateTheme(),
        home: Scaffold(
          body: MealPlanCard(
            slot: {
              'slot': 'dinner',
              'cooked': false,
              'macros': {'kcal': 520, 'protein': 40, 'carbs': 30, 'fat': 20, 'sugar': 4},
              'recipe': {
                'title': 'Lemon roast chicken and potatoes',
                'summary': 'One-tin supper.',
                'method_steps': ['Heat the oven to 200°C.', 'Roast until cooked.'],
                'scaled_ingredients': [
                  {'name': 'Chicken breast', 'quantity': 600, 'unit': 'g'},
                ],
              },
            },
            onCooked: () {},
            onRemove: () {},
          ),
        ),
      ),
    );
    expect(find.text('Dinner'), findsOneWidget);
    expect(find.text('Lemon roast chicken and potatoes'), findsOneWidget);
    expect(find.text('One-tin supper.'), findsOneWidget);
    expect(find.textContaining('Chicken breast'), findsOneWidget);
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('Heat the oven to 200°C.'), findsOneWidget);
    expect(find.textContaining('kcal'), findsWidgets);
  });

  testWidgets('new recipe form uses Add step and Add ingredient', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = Session();
    await tester.pumpWidget(
      MaterialApp(
        theme: weekOnPlateTheme(),
        home: RecipeEditScreen(session: session),
      ),
    );
    expect(find.text('Add step'), findsOneWidget);
    expect(find.text('Add ingredient'), findsOneWidget);
    expect(find.text('Step 1'), findsOneWidget);
    await tester.tap(find.text('Add step'));
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
