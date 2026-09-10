import 'package:flutter_test/flutter_test.dart';
import 'package:week_on_plate/domain/extract.dart';

void main() {
  test('extracts a caption into a confirmable draft', () {
    final draft = extractFromCaption('''High protein chicken bowl
Serves 2

Ingredients:
- 400g chicken breast
- 200g rice

Method:
1. Cook the rice.
''');
    expect(draft['title'].toString().toLowerCase(), contains('chicken bowl'));
    expect(draft['serves'], 2);
    expect((draft['ingredients'] as List).length, 2);
  });

  test('does not invent an ingredient from 30 mins', () {
    final draft = extractFromCaption('''Lemon roast chicken
30 mins
Just some caption waffle
''');
    expect(draft['ingredients'], isEmpty);
    expect(draft['minutes'], 30);
  });
}
