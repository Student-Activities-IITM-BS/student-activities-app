import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_activities/core/app_preferences.dart';
import 'package:student_activities/core/theme.dart';
import 'package:student_activities/core/widgets.dart';
import 'package:student_activities/screens/search/search_screen.dart';
import 'package:student_activities/screens/settings/about_screen.dart';

void main() {
  testWidgets('app card uses the active Material theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(AppVisualStyle.material),
        home: const Scaffold(body: AppCard(child: Text('Student Activities'))),
      ),
    );

    expect(find.text('Student Activities'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
  });

  testWidgets('UIX theme builds its native control palette', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(AppVisualStyle.uix),
        home: const Scaffold(
          body: FilledButton(onPressed: null, child: Text('Continue')),
        ),
      ),
    );

    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('about activity fits a compact phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(AppVisualStyle.uix),
        home: const AboutScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Abhi'), 500);
    await tester.pumpAndSettle();
    expect(find.text('Abhi'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Open source licenses'), 500);
    await tester.pumpAndSettle();
    expect(find.text('Open source licenses'), findsOneWidget);
    await tester.tap(find.text('Open source licenses'));
    await tester.pumpAndSettle();
    expect(find.text('Licenses'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('assistant composer clears focus when tapped outside', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(AppVisualStyle.material),
        home: const Scaffold(body: SearchScreen()),
      ),
    );

    final field = find.byType(TextField);
    await tester.tap(field);
    await tester.pump();
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isTrue);

    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    expect(editable.focusNode.hasFocus, isFalse);
  });
}
