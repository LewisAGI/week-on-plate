const nutritionPer100g = <String, Map<String, double>>{
  'chicken breast': {'kcal': 165, 'protein': 31, 'carbs': 0, 'fat': 3.6, 'sugar': 0},
  'chicken': {'kcal': 165, 'protein': 31, 'carbs': 0, 'fat': 3.6, 'sugar': 0},
  'salmon': {'kcal': 208, 'protein': 20, 'carbs': 0, 'fat': 13, 'sugar': 0},
  'oats': {'kcal': 389, 'protein': 17, 'carbs': 66, 'fat': 7, 'sugar': 1},
  'rolled oats': {'kcal': 389, 'protein': 17, 'carbs': 66, 'fat': 7, 'sugar': 1},
  'rice': {'kcal': 130, 'protein': 2.7, 'carbs': 28, 'fat': 0.3, 'sugar': 0},
  'olive oil': {'kcal': 884, 'protein': 0, 'carbs': 0, 'fat': 100, 'sugar': 0},
  'turkey mince': {'kcal': 135, 'protein': 30, 'carbs': 0, 'fat': 1, 'sugar': 0},
  'egg': {'kcal': 155, 'protein': 13, 'carbs': 1.1, 'fat': 11, 'sugar': 1.1},
  'eggs': {'kcal': 155, 'protein': 13, 'carbs': 1.1, 'fat': 11, 'sugar': 1.1},
};

const unitGrams = <String, double>{
  'g': 1,
  'ml': 1,
  'tbsp': 15,
  'tsp': 5,
  'each': 60,
  'kg': 1000,
  'l': 1000,
};

Map<String, double>? lookupNutrition(String name) {
  final n = name.toLowerCase().trim();
  if (nutritionPer100g.containsKey(n)) return nutritionPer100g[n];
  final keys = nutritionPer100g.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final key in keys) {
    if (n.contains(key)) return nutritionPer100g[key];
  }
  return null;
}

Map<String, double> emptyMacros() => {
      'kcal': 0,
      'protein': 0,
      'carbs': 0,
      'fat': 0,
      'sugar': 0,
    };

double? gramsForIngredient(num? quantity, String? unit) {
  if (quantity == null) return null;
  final factor = unitGrams[(unit ?? 'g').toLowerCase()];
  if (factor == null) return null;
  return quantity.toDouble() * factor;
}

Map<String, double> macrosForIngredient(Map<String, dynamic> ingredient) {
  final nut = lookupNutrition(ingredient['name'] as String? ?? '');
  final grams = gramsForIngredient(
    ingredient['quantity'] as num?,
    ingredient['unit'] as String?,
  );
  if (nut == null || grams == null) return emptyMacros();
  final f = grams / 100;
  return {
    'kcal': ((nut['kcal']! * f) * 10).round() / 10,
    'protein': ((nut['protein']! * f) * 10).round() / 10,
    'carbs': ((nut['carbs']! * f) * 10).round() / 10,
    'fat': ((nut['fat']! * f) * 10).round() / 10,
    'sugar': ((nut['sugar']! * f) * 10).round() / 10,
  };
}

Map<String, double> macrosForIngredients(List<Map<String, dynamic>> ingredients) {
  final total = emptyMacros();
  for (final ing in ingredients) {
    final m = macrosForIngredient(ing);
    for (final key in total.keys) {
      total[key] = ((total[key]! + m[key]!) * 10).round() / 10;
    }
  }
  return total;
}

Map<String, double> scaleMacros(Map<String, double> macros, num factor) {
  final f = factor.toDouble();
  return {
    for (final e in macros.entries) e.key: ((e.value * f) * 10).round() / 10,
  };
}
