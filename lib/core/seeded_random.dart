/// Deterministic pseudo-random numbers.
///
/// `dart:math`'s `Random(seed)` does not promise the same sequence across
/// SDK versions, but "same day, same wallpaper" must hold after an update,
/// so dailywall uses its own small generator (mulberry32) and string hash
/// (FNV-1a).
class SeededRandom {
  SeededRandom(int seed) : _state = seed & 0xFFFFFFFF;

  /// Seed from any number of parts, e.g. `SeededRandom.of(['bg', day, 'motivation'])`.
  factory SeededRandom.of(List<Object> parts) => SeededRandom(hashParts(parts));

  int _state;

  /// Next unsigned 32-bit value.
  int nextUint32() {
    _state = (_state + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _state;
    t = _imul(t ^ (t >>> 15), t | 1);
    t ^= (t + _imul(t ^ (t >>> 7), t | 61)) & 0xFFFFFFFF;
    return (t ^ (t >>> 14)) & 0xFFFFFFFF;
  }

  /// Uniform double in [0, 1).
  double nextDouble() => nextUint32() / 4294967296.0;

  /// Uniform int in [0, max).
  int nextInt(int max) {
    assert(max > 0);
    return (nextDouble() * max).floor();
  }

  /// Uniform double in [min, max).
  double range(double min, double max) => min + (max - min) * nextDouble();

  bool nextBool() => nextUint32() & 1 == 1;

  T pick<T>(List<T> items) => items[nextInt(items.length)];

  /// Fisher–Yates shuffle into a new list.
  List<T> shuffled<T>(Iterable<T> items) {
    final list = items.toList();
    for (var i = list.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
    return list;
  }

  static int _imul(int a, int b) => (a * b) & 0xFFFFFFFF;

  /// 32-bit FNV-1a over the UTF-16 code units of the joined parts.
  static int hashParts(List<Object> parts) {
    var hash = 0x811C9DC5;
    for (final unit in parts.join('\u0000').codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }
}
