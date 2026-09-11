import 'package:flutter_test/flutter_test.dart';
import 'package:week_on_plate/domain/method.dart';
import 'package:week_on_plate/domain/scale.dart';
import 'package:week_on_plate/widgets.dart';

void main() {
  test('splits a paragraph method into numbered steps', () {
    final steps = methodToSteps(
      'Heat the oven to 200°C. Toss potatoes, chicken, lemon, garlic and oil on a tin. Roast 45–50 minutes until the chicken is cooked through. Rest five minutes, then serve.',
    );
    expect(steps.length, 4);
    expect(steps.first, contains('Heat the oven'));
    expect(steps.last, contains('Rest five minutes'));
  });

  test('keeps newline steps and strips 1. prefixes', () {
    expect(methodToSteps('1. Cook the rice.\n2. Fry the chicken.'), ['Cook the rice.', 'Fry the chicken.']);
  });

  test('reads method_steps from a recipe map', () {
    expect(
      stepsFromRecipe({
        'method': 'ignored paragraph.',
        'method_steps': ['Season.', 'Plate up.'],
      }),
      ['Season.', 'Plate up.'],
    );
  });

  test('softens the teen household line', () {
    expect(teenTip, contains('For teens: consider teenage eating habits'));
    expect(teenTip.toLowerCase().contains('consider teenage diets'), isFalse);
  });

  test('orders meals breakfast then lunch then dinner', () {
    final ordered = slotsInMealOrder([
      {'slot': 'dinner'},
      {'slot': 'breakfast'},
      {'slot': 'lunch'},
    ]);
    expect(ordered.map((s) => s['slot']).toList(), ['breakfast', 'lunch', 'dinner']);
    expect(slotLabel('lunch'), 'Lunch');
    expect(weekdayShort('2026-09-14'), 'Mon');
  });
}
