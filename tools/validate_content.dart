// Content report for assets/content/*.json.
//
//   dart run tools/validate_content.dart
//
// Checks every category file with the same rules the app uses at startup
// and prints item counts per category and level, missing translations,
// duplicate ids/content and too-long texts. Exits with code 1 on errors.
//
// The interface languages are read from lib/l10n/app_<lang>.arb, so adding
// a language only needs a new ARB file; this script then reports every
// item that is missing the new translation.

import 'dart:convert';
import 'dart:io';

import 'package:dayleaf/data/content_models.dart';
import 'package:dayleaf/data/content_schema.dart';

void main(List<String> args) {
  final root = Directory.current;
  final languages = _languagesFromArb(Directory('${root.path}/lib/l10n'));
  stdout.writeln('Interface languages: ${languages.join(', ')}\n');

  final results = <CategoryValidation>[];
  var fileErrors = 0;
  for (final category in ContentCatalog.categories) {
    final file = File('${root.path}/${category.assetPath}');
    if (!file.existsSync()) {
      stderr.writeln('MISSING FILE: ${category.assetPath}');
      fileErrors++;
      continue;
    }
    Object? json;
    try {
      json = jsonDecode(file.readAsStringSync());
    } on FormatException catch (e) {
      stderr.writeln('INVALID JSON in ${category.assetPath}: ${e.message}');
      fileErrors++;
      continue;
    }
    results.add(validateCategory(category, json, languages: languages));
  }
  final crossIssues = validateAcrossCategories(results);

  stdout.writeln('Items per category');
  for (final r in results) {
    final premium = r.items.where((i) => i.isPremium).length;
    stdout.writeln(
      '  ${r.category.id.padRight(20)} ${r.items.length.toString().padLeft(4)} valid'
      '${r.rejectedIds.isEmpty ? '' : ', ${r.rejectedIds.length} rejected'}'
      '${premium == 0 ? '' : ', $premium premium'}',
    );
    if (r.category.kind == ContentKind.word) {
      for (final level in CefrLevel.values) {
        final n = r.items
            .whereType<WordItem>()
            .where((w) => w.level == level)
            .length;
        stdout.writeln('      ${level.code}: $n');
      }
    }
  }

  final all = [...results.expand((r) => r.issues), ...crossIssues];
  final missing = all
      .where((i) => i.message.startsWith('missing translation'))
      .toList();
  final duplicates = all
      .where(
        (i) =>
            i.message.startsWith('duplicate') ||
            i.message.startsWith('same content') ||
            i.message.contains('also used in'),
      )
      .toList();
  final tooLong = all.where((i) => i.message.contains('limit is')).toList();
  final other = all
      .where(
        (i) =>
            !missing.contains(i) &&
            !duplicates.contains(i) &&
            !tooLong.contains(i),
      )
      .toList();

  void section(String title, List<ContentIssue> issues) {
    stdout.writeln('\n$title: ${issues.isEmpty ? 'none' : issues.length}');
    for (final i in issues) {
      stdout.writeln('  $i');
    }
  }

  section('Missing translations', missing);
  section('Duplicates', duplicates);
  section('Too long', tooLong);
  section('Other issues', other);

  final errorCount = fileErrors + all.where((i) => i.isError).length;
  stdout.writeln(
    errorCount == 0 ? '\nOK: no errors.' : '\nFAILED: $errorCount error(s).',
  );
  exitCode = errorCount == 0 ? 0 : 1;
}

List<String> _languagesFromArb(Directory dir) {
  final pattern = RegExp(r'^app_([a-z]{2,3}(?:_[A-Z]{2})?)\.arb$');
  final langs = <String>[
    for (final f in dir.listSync().whereType<File>())
      if (pattern.firstMatch(f.uri.pathSegments.last) case final m?)
        m.group(1)!,
  ]..sort();
  if (langs.isEmpty) {
    stderr.writeln('No ARB files found in ${dir.path}');
    exit(2);
  }
  return langs;
}
