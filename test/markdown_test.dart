import 'package:flutter_test/flutter_test.dart';
import 'package:student_activities/core/markdown.dart';

void main() {
  test('links bare URLs without nesting existing Markdown destinations', () {
    expect(
      normalizeMarkdownLinks(
        'Read https://iitmbs.org/privacy. [Portal](https://iitmbs.org)',
      ),
      'Read [https://iitmbs.org/privacy](https://iitmbs.org/privacy). '
      '[Portal](https://iitmbs.org)',
    );
  });
}
