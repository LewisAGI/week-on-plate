const int defaultAdults = 2;
const int defaultUnder18s = 0;

const String teenTip =
    'Older teenagers often eat like adults. If that is your house, count them as adults rather than under-18s.';

int householdHeads(int adults, int under18s) {
  final a = adults < 0 ? 0 : adults;
  final u = under18s < 0 ? 0 : under18s;
  return a + u;
}

double scaleFactor(num serves, int adults, int under18s) {
  final s = serves.toDouble();
  if (s <= 0) return 1;
  final heads = householdHeads(adults, under18s);
  if (heads <= 0) return 1;
  return heads / s;
}

double? scaleQuantity(num? quantity, num factor) {
  if (quantity == null) return null;
  return (quantity.toDouble() * factor.toDouble() * 1000).round() / 1000;
}
