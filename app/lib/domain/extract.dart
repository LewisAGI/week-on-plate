final _servesRe = RegExp(r'serves?\s+(\d+(?:\.\d+)?)', caseSensitive: false);
final _qtyLineRe = RegExp(
  r'^\s*(?:[-*•]\s*)?(\d+(?:\.\d+)?)\s*(kg|g|ml|l|tbsp|tsp|cups?|cloves?|x)?\s+(.+?)\s*$',
  caseSensitive: false,
);

Map<String, dynamic> extractFromCaption(String text) {
  final raw = text.replaceAll('\r\n', '\n').trim();
  final lines = raw.split('\n').map((l) => l.trim()).toList();
  final nonEmpty = lines.where((l) => l.isNotEmpty).toList();
  var title = nonEmpty.firstWhere(
    (l) => !l.startsWith('http') && !_servesRe.hasMatch(l),
    orElse: () => 'Imported recipe',
  );
  title = title.replaceFirst(RegExp(r'^#+\s*'), '').trim();
  if (title.isEmpty) title = 'Imported recipe';

  var serves = 2;
  final servesHit = _servesRe.firstMatch(raw);
  if (servesHit != null) serves = int.tryParse(servesHit.group(1)!) ?? 2;

  final ingredients = <Map<String, dynamic>>[];
  final methodLines = <String>[];
  var section = 'unknown';
  for (final line in lines) {
    final lower = line.toLowerCase();
    if (RegExp(r'^ingredients?\b').hasMatch(lower)) {
      section = 'ingredients';
      continue;
    }
    if (RegExp(r'^(method|steps|directions|instructions)\b').hasMatch(lower)) {
      section = 'method';
      continue;
    }
    final qty = _qtyLineRe.firstMatch(line);
    if (qty != null) {
      ingredients.add({
        'name': qty.group(3)!.trim(),
        'quantity': num.parse(qty.group(1)!),
        'unit': (qty.group(2) ?? 'each').toLowerCase(),
      });
      continue;
    }
    if (section == 'method' && line.isNotEmpty) {
      methodLines.add(line.replaceFirst(RegExp(r'^\d+[.)]\s*'), ''));
    }
  }

  return {
    'title': title,
    'summary': 'Imported from a pasted caption',
    'serves': serves,
    'method': methodLines.join('\n'),
    'ingredients': ingredients,
    'source_text': raw,
    'extractor': 'heuristic',
  };
}
