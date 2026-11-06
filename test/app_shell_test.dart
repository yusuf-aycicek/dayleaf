import 'package:dailywall/app/app.dart';
import 'package:dailywall/l10n/gen/app_localizations.dart';
import 'package:dailywall/ui/labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (locale, expected) in [
    (const Locale('en'), 'Today'),
    (const Locale('tr'), 'Bugün'),
  ]) {
    testWidgets('app shell is localized: ${locale.languageCode}', (
      tester,
    ) async {
      await tester.pumpWidget(
        DailyWallApp(
          locale: locale,
          home: Builder(
            builder: (context) => Text(AppLocalizations.of(context).homeTitle),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(expected), findsOneWidget);
    });
  }

  test('every supported locale has an ARB translation', () {
    expect(
      AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet(),
      {'en', 'tr'},
    );
  });

  test('every language names itself in its own ARB file', () {
    expect(languageName('tr'), 'Türkçe');
    expect(languageName('en'), 'English');
    expect(languageName('xx'), 'xx');
  });
}
