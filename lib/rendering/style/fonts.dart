/// Font families bundled in `assets/fonts` and declared in pubspec.yaml.
/// All are from Google Fonts under the SIL Open Font License and cover
/// Turkish letters (checked by test/rendering/fonts_test.dart).
abstract final class BundledFonts {
  static const manrope = 'Manrope';
  static const lora = 'Lora';
  static const anton = 'Anton';
  static const jetBrainsMono = 'JetBrainsMono';
  static const instrumentSerif = 'InstrumentSerif';
  static const literata = 'Literata';
  static const barlowCondensed = 'BarlowCondensed';
  static const bricolage = 'BricolageGrotesque';
  static const plexSans = 'IBMPlexSans';
  static const plexMono = 'IBMPlexMono';
  static const spaceGrotesk = 'SpaceGrotesk';
  static const fraunces = 'Fraunces';

  /// Fallback for glyphs the chosen fonts lack, above all the IPA symbols
  /// of pronunciations (none of the display and body fonts has them).
  static const gentium = 'GentiumBookPlus';
  static const fallback = [gentium];

  static const families = {
    manrope,
    lora,
    anton,
    jetBrainsMono,
    instrumentSerif,
    literata,
    barlowCondensed,
    bricolage,
    plexSans,
    plexMono,
    spaceGrotesk,
    fraunces,
    gentium,
  };

  /// Display names and license files, for About → Licenses.
  static const licenses = [
    ('Manrope', 'OFL-Manrope.txt'),
    ('Lora', 'OFL-Lora.txt'),
    ('Anton', 'OFL-Anton.txt'),
    ('JetBrains Mono', 'OFL-JetBrainsMono.txt'),
    ('Instrument Serif', 'OFL-InstrumentSerif.txt'),
    ('Literata', 'OFL-Literata.txt'),
    ('Barlow Condensed', 'OFL-BarlowCondensed.txt'),
    ('Bricolage Grotesque', 'OFL-BricolageGrotesque.txt'),
    ('IBM Plex Sans', 'OFL-IBMPlexSans.txt'),
    ('IBM Plex Mono', 'OFL-IBMPlexMono.txt'),
    ('Space Grotesk', 'OFL-SpaceGrotesk.txt'),
    ('Fraunces', 'OFL-Fraunces.txt'),
    ('Gentium Book Plus', 'OFL-GentiumBookPlus.txt'),
  ];
}
