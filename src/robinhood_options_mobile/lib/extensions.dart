extension EnumExtensions on Enum {
  String enumValue() {
    return toString().split('.').last;
  }
}

extension StringExtensions on String {
  E parseEnum<E extends Enum>(List<E> values, E defaultValue) {
    final Map<String, E> statusMap = {
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
