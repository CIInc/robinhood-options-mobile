extension EnumExtensions<T extends Enum> on T {
  String enumValue() {
    return toString().split('.').last;
  }
}

extension StringExtensions<T extends Enum> on String {
  T parseEnum(List<T> values, T defaultValue) {
    final Map<String, T> statusMap = {
      for (var status in values) status.enumValue(): status
    };

    if (statusMap.containsKey(this)) {
      return statusMap[this]!;
    } else {
      return defaultValue;
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
