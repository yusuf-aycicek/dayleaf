/// Source of "now", injected everywhere so tests (and the debug menu) can
/// move time without touching the device clock.
abstract interface class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

class FixedClock implements Clock {
  FixedClock(this.value);

  DateTime value;

  @override
  DateTime now() => value;
}

/// Shifts another clock by whole days (debug "pretend it is tomorrow").
class OffsetClock implements Clock {
  const OffsetClock(this.base, this.days);

  final Clock base;
  final int days;

  @override
  DateTime now() => base.now().add(Duration(days: days));
}

/// Number of local calendar days since 1970-01-01. A "day" in Dayleaf is
/// the user's local date, so the wallpaper changes at local midnight and
/// daylight-saving shifts never skip or repeat a day.
int dayIndexOf(DateTime time) =>
    DateTime.utc(time.year, time.month, time.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

/// The calendar date (year, month, day) of a [dayIndexOf] value.
DateTime dateOfDayIndex(int day) => DateTime.fromMillisecondsSinceEpoch(
  day * Duration.millisecondsPerDay,
  isUtc: true,
);
