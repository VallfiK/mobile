extension DateTimeExtensions on DateTime {
  bool isBeforeOrAtSameMomentAs(DateTime other) {
    return isBefore(other) || isAtSameMomentAs(other);
  }
} 