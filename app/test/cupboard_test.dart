import 'package:flutter_test/flutter_test.dart';
import 'package:week_on_plate/domain/cupboard.dart';

void main() {
  test('ships a cold-start staple list', () {
    expect(coldStartStaples.length >= 8, isTrue);
    expect(coldStartStaples.any((s) => (s['name'] as String).toLowerCase().contains('olive oil')), isTrue);
  });

  test('suggests decrement or untick after a meal is cooked', () {
    final suggestions = suggestAdjustments(
      [
        {'name': 'Rice', 'quantity': 160, 'unit': 'g'},
        {'name': 'Olive oil', 'quantity': 15, 'unit': 'ml'},
      ],
      [
        {'id': 'c1', 'name': 'Rice', 'quantity': 500, 'unit': 'g', 'in_stock': 1},
        {'id': 'c2', 'name': 'Olive oil', 'quantity': 15, 'unit': 'ml', 'in_stock': 1},
      ],
    );
    final rice = suggestions.firstWhere((s) => s.id == 'c1');
    expect(rice.action, 'decrement');
    expect(rice.remaining, 340);
    final after = applyAdjustment({'id': 'c1', 'quantity': 500, 'in_stock': 1}, rice);
    expect(after['quantity'], 340);
  });
}
