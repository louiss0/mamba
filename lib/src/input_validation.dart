/// Shared rules for checking declared defaults and explicitly parsed values.
bool matchesEntireValue(RegExp regex, String value) {
  final match = regex.firstMatch(value);
  return match != null && match.start == 0 && match.end == value.length;
}

bool followsNumericStep(num value, num origin, num step) {
  final increments = (value.toDouble() - origin.toDouble()) / step;
  return increments.isFinite &&
      (increments - increments.round()).abs() <= 1e-12;
}
