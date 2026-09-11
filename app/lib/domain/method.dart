final _numberPrefix = RegExp(r'^\s*(?:\d+[.)]\s+|[-*•]\s+)');
final _sentenceSplit = RegExp(r'(?<=[.!?])\s+(?=[A-Z0-9])');

String _cleanStep(String value) {
  return value.replaceFirst(_numberPrefix, '').replaceAll(RegExp(r'\s+'), ' ').trim();
}

List<String> _splitSentences(String text) {
  final raw = text.trim();
  if (raw.isEmpty) return const [];
  final cleaned = raw.split(_sentenceSplit).map(_cleanStep).where((s) => s.isNotEmpty).toList();
  return cleaned.isEmpty ? [raw] : cleaned;
}

/// Turn a stored method string and/or a steps array into numbered display steps.
List<String> methodToSteps(dynamic method, {List<dynamic>? methodSteps}) {
  if (methodSteps != null) {
    final fromArray = methodSteps.map((s) => _cleanStep('$s')).where((s) => s.isNotEmpty).toList();
    if (fromArray.isNotEmpty) return fromArray;
  }
  final raw = (method ?? '').toString().replaceAll('\r\n', '\n').trim();
  if (raw.isEmpty) return const [];
  final lines = raw.split(RegExp(r'\n+')).map(_cleanStep).where((s) => s.isNotEmpty).toList();
  if (lines.length > 1) return lines;
  return _splitSentences(lines.first);
}

List<String> stepsFromRecipe(Map<String, dynamic> recipe) {
  final raw = recipe['method_steps'];
  return methodToSteps(
    recipe['method'],
    methodSteps: raw is List ? raw : null,
  );
}

String stepsToMethod(List<String> steps) => methodToSteps(null, methodSteps: steps).join('\n');
