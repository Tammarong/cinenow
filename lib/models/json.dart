/// Helpers for reading loosely-typed JSON / Realtime Database snapshots.
///
/// RTDB returns arrays as `List` when keys are 0..n, but as `Map` when the
/// list is sparse, and numbers as `int` or `double` depending on the value.
library;

/// Always returns a new, mutable map (callers may add to it).
Map<String, dynamic> asMap(Object? value) {
  if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
  return <String, dynamic>{};
}

List<Object?> asList(Object? value) {
  if (value is List) return value.where((e) => e != null).toList();
  if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()
      ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
    return [for (final k in keys) value[k] ?? value[int.tryParse(k)]].where((e) => e != null).toList();
  }
  return const [];
}

List<String> asStringList(Object? value) => asList(value).map((e) => e.toString()).toList();

String asString(Object? value, [String fallback = '']) => value?.toString() ?? fallback;

String? asStringOrNull(Object? value) {
  final s = value?.toString();
  return (s == null || s.isEmpty) ? null : s;
}

int asInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? asIntOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? asDoubleOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

bool asBool(Object? value) => value == true || value == 'true';
