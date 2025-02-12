bool jsonMapEquals(dynamic a, dynamic b) {
  if (identical(a, b)) {
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (var key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!jsonMapEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    final length = a.length;
    if (length != b.length) return false;
    for (var i = 0; i < length; i++) {
      if (!jsonMapEquals(a[i], b[i])) return false;
    }
    return true;
  }
  assert(a is num || a is String || a is bool || a == null);
  assert(b is num || b is String || b is bool || b == null);
  return a == b;
}
