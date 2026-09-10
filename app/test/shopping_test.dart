import 'package:flutter_test/flutter_test.dart';
import 'package:week_on_plate/domain/shopping.dart';

void main() {
  test('merges the same ingredient across meals and converts kg', () {
    final merged = mergeIngredients([
      {'name': 'Chicken breast', 'quantity': 400, 'unit': 'g'},
      {'name': 'chicken breasts', 'quantity': 0.2, 'unit': 'kg'},
      {'name': 'Olive oil', 'quantity': 2, 'unit': 'tbsp'},
    ]);
    final chicken = merged.firstWhere((m) => m.normalized == 'chicken breast');
    expect(chicken.quantity, 600);
    expect(chicken.unit, 'g');
  });

  test('subtracts cupboard stock from the buy list', () {
    final merged = mergeIngredients([
      {'name': 'Rice', 'quantity': 500, 'unit': 'g'},
      {'name': 'Onions', 'quantity': 2, 'unit': 'each'},
    ]);
    final split = subtractCupboard(merged, [
      {'name': 'rice', 'quantity': 500, 'unit': 'g', 'in_stock': 1},
      {'name': 'Onions', 'quantity': 1, 'unit': 'each', 'in_stock': 1},
    ]);
    expect(split.alreadyHave.any((i) => i.normalized == 'rice'), isTrue);
    final onions = split.buy.firstWhere((i) => i.normalized == 'onion');
    expect(onions.quantity, 1);
  });
}
