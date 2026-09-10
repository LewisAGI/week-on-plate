import 'package:flutter_test/flutter_test.dart';
import 'package:week_on_plate/domain/macros.dart';

void main() {
  test('sums calories, protein, carbs, fat and sugar from ingredients', () {
    final m = macrosForIngredients([
      {'name': 'Chicken breast', 'quantity': 200, 'unit': 'g'},
      {'name': 'Olive oil', 'quantity': 1, 'unit': 'tbsp'},
    ]);
    expect(m['kcal']! > 200, isTrue);
    expect(m['protein']! > 50, isTrue);
    expect(m['fat']! > 10, isTrue);
    expect(m.containsKey('sugar'), isTrue);
    expect(m.containsKey('carbs'), isTrue);
  });

  test('scales a recipe macros to the household', () {
    final base = macrosForIngredients([
      {'name': 'Salmon', 'quantity': 200, 'unit': 'g'},
    ]);
    final doubled = scaleMacros(base, 2);
    expect(doubled['kcal'], ((base['kcal']! * 2) * 10).round() / 10);
  });
}
