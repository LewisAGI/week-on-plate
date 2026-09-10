String normalizeName(String name) {
  var n = name.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), ' ');
  n = n.replaceAll(RegExp(r'\s+'), ' ').trim();
  n = n.replaceFirst(RegExp(r'ies$'), 'y');
  n = n.replaceFirst(RegExp(r'oes$'), 'o');
  n = n.replaceFirst(RegExp(r'ses$'), 's');
  n = n.replaceFirst(RegExp(r's$'), '');
  return n;
}

({String unit, num factor}) canonicalUnit(String? unit) {
  final u = (unit ?? '').toLowerCase().trim();
  if (['kg', 'kilogram', 'kilograms'].contains(u)) {
    return (unit: 'g', factor: 1000);
  }
  if (['l', 'litre', 'litres', 'liter', 'liters'].contains(u)) {
    return (unit: 'ml', factor: 1000);
  }
  if (['g', 'gram', 'grams'].contains(u)) return (unit: 'g', factor: 1);
  if (['ml', 'millilitre', 'millilitres', 'milliliter', 'milliliters']
      .contains(u)) {
    return (unit: 'ml', factor: 1);
  }
  if (['tbsp', 'tablespoon', 'tablespoons'].contains(u)) {
    return (unit: 'ml', factor: 15);
  }
  if (['tsp', 'teaspoon', 'teaspoons'].contains(u)) {
    return (unit: 'ml', factor: 5);
  }
  if (['', 'x', 'each', 'unit', 'units', 'item', 'items'].contains(u)) {
    return (unit: 'each', factor: 1);
  }
  return (unit: u, factor: 1);
}

class MergedIngredient {
  MergedIngredient({
    required this.name,
    required this.normalized,
    required this.quantity,
    required this.unit,
  });

  final String name;
  final String normalized;
  double? quantity;
  final String unit;
}

List<MergedIngredient> mergeIngredients(List<Map<String, dynamic>> items) {
  final map = <String, MergedIngredient>{};
  for (final item in items) {
    final rawName = (item['name'] as String? ?? '').trim();
    final normalized = normalizeName(rawName);
    if (normalized.isEmpty) continue;
    final cu = canonicalUnit(item['unit'] as String?);
    final rawQty = item['quantity'];
    final qty = rawQty == null ? null : (rawQty as num).toDouble() * cu.factor;
    final key = '$normalized|${cu.unit}';
    final prev = map[key];
    if (prev == null) {
      map[key] = MergedIngredient(
        name: rawName,
        normalized: normalized,
        quantity: qty,
        unit: cu.unit,
      );
    } else if (prev.quantity != null && qty != null) {
      prev.quantity = prev.quantity! + qty;
    } else if (prev.quantity == null && qty != null) {
      prev.quantity = qty;
    }
  }
  return map.values.map((row) {
    final q = row.quantity;
    return MergedIngredient(
      name: row.name,
      normalized: row.normalized,
      quantity: q == null ? null : (q * 1000).round() / 1000,
      unit: row.unit,
    );
  }).toList();
}

class ShoppingSplit {
  ShoppingSplit({required this.buy, required this.alreadyHave});
  final List<MergedIngredient> buy;
  final List<MergedIngredient> alreadyHave;
}

ShoppingSplit subtractCupboard(
  List<MergedIngredient> merged,
  List<Map<String, dynamic>> cupboard,
) {
  final stock = <String, double>{};
  for (final item in cupboard) {
    if ((item['in_stock'] as num? ?? 1) == 0) continue;
    final cu = canonicalUnit(item['unit'] as String?);
    final key = '${normalizeName(item['name'] as String? ?? '')}|${cu.unit}';
    final raw = item['quantity'];
    stock[key] = raw == null ? double.infinity : (raw as num).toDouble() * cu.factor;
  }
  final buy = <MergedIngredient>[];
  final have = <MergedIngredient>[];
  for (final row in merged) {
    final key = '${row.normalized}|${row.unit}';
    final got = stock[key] ?? 0;
    if (got == double.infinity || (row.quantity == null && got > 0)) {
      have.add(row);
      continue;
    }
    if (row.quantity == null) {
      buy.add(row);
      continue;
    }
    final needed = ((row.quantity! - got) * 1000).round() / 1000;
    if (needed <= 0) {
      have.add(row);
    } else {
      buy.add(MergedIngredient(
        name: row.name,
        normalized: row.normalized,
        quantity: needed,
        unit: row.unit,
      ));
    }
  }
  return ShoppingSplit(buy: buy, alreadyHave: have);
}
