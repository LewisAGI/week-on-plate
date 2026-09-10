import 'shopping.dart';

const coldStartStaples = [
  {'name': 'Olive oil', 'unit': 'ml', 'quantity': 250},
  {'name': 'Salt', 'unit': 'g', 'quantity': 200},
  {'name': 'Black pepper', 'unit': 'g', 'quantity': 50},
  {'name': 'Garlic', 'unit': 'each', 'quantity': 1},
  {'name': 'Onions', 'unit': 'each', 'quantity': 3},
  {'name': 'Tinned tomatoes', 'unit': 'g', 'quantity': 400},
  {'name': 'Pasta', 'unit': 'g', 'quantity': 500},
  {'name': 'Rice', 'unit': 'g', 'quantity': 500},
  {'name': 'Oats', 'unit': 'g', 'quantity': 500},
  {'name': 'Eggs', 'unit': 'each', 'quantity': 6},
  {'name': 'Butter', 'unit': 'g', 'quantity': 250},
  {'name': 'Plain flour', 'unit': 'g', 'quantity': 500},
  {'name': 'Stock cubes', 'unit': 'each', 'quantity': 8},
  {'name': 'Soy sauce', 'unit': 'ml', 'quantity': 150},
  {'name': 'Honey', 'unit': 'g', 'quantity': 200},
  {'name': 'Lemons', 'unit': 'each', 'quantity': 2},
];

class StockSuggestion {
  StockSuggestion({
    required this.name,
    required this.unit,
    required this.action,
    this.id,
    this.used,
    this.remaining,
  });

  final String? id;
  final String name;
  final String unit;
  final String action;
  final double? used;
  final double? remaining;
}

List<StockSuggestion> suggestAdjustments(
  List<Map<String, dynamic>> recipeIngredients,
  List<Map<String, dynamic>> cupboard,
) {
  final suggestions = <StockSuggestion>[];
  for (final ing in recipeIngredients) {
    final n = normalizeName(ing['name'] as String? ?? '');
    final unit = canonicalUnit(ing['unit'] as String?).unit;
    final match = cupboard.cast<Map<String, dynamic>?>().firstWhere(
          (c) =>
              normalizeName(c?['name'] as String? ?? '') == n &&
              canonicalUnit(c?['unit'] as String?).unit == unit,
          orElse: () => null,
        );
    final used = (ing['quantity'] as num?)?.toDouble();
    if (match == null) {
      suggestions.add(StockSuggestion(name: ing['name'] as String? ?? n, unit: unit, action: 'none', used: used));
      continue;
    }
    final have = (match['quantity'] as num?)?.toDouble();
    if (used == null || have == null) {
      suggestions.add(StockSuggestion(
        id: match['id'] as String?,
        name: match['name'] as String,
        unit: unit,
        action: 'untick',
        used: used,
        remaining: 0,
      ));
    } else {
      final remaining = (((have - used) * 1000).round() / 1000).clamp(0, double.infinity);
      suggestions.add(StockSuggestion(
        id: match['id'] as String?,
        name: match['name'] as String,
        unit: unit,
        action: remaining == 0 ? 'untick' : 'decrement',
        used: used,
        remaining: remaining.toDouble(),
      ));
    }
  }
  return suggestions;
}

Map<String, dynamic> applyAdjustment(Map<String, dynamic> item, StockSuggestion suggestion) {
  if (suggestion.action == 'untick') {
    return {...item, 'in_stock': 0, 'quantity': 0};
  }
  if (suggestion.action == 'decrement') {
    return {...item, 'in_stock': 1, 'quantity': suggestion.remaining};
  }
  return item;
}
