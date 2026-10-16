import 'package:flutter_test/flutter_test.dart';
import 'package:week_on_plate/domain/scale.dart';

void main() {
  test('defaults to two adults', () {
    expect(defaultAdults, 2);
    expect(householdHeads(2, 0), 2);
  });

  test('counts under-18s as heads', () {
    expect(householdHeads(2, 1), 3);
  });

  test('scales a 4-serve recipe onto two adults', () {
    expect(scaleFactor(4, 2, 0), 0.5);
    expect(scaleQuantity(400, 0.5), 200);
  });

  test('scales a 2-serve recipe onto two adults and one child', () {
    expect(scaleFactor(2, 2, 1), 1.5);
    expect(scaleQuantity(160, 1.5), 240);
  });
}
