/// Date helpers for the AKTH ten-working-day posting cycle.
/// Weekends are excluded; public holidays are not currently considered.
class PostingPeriod {
  const PostingPeriod._();

  static bool isWeekday(DateTime date) =>
      date.weekday >= DateTime.monday && date.weekday <= DateTime.friday;

  static DateTime nextWeekday(DateTime date) {
    var result = DateTime(date.year, date.month, date.day);
    while (!isWeekday(result)) {
      result = result.add(const Duration(days: 1));
    }
    return result;
  }

  /// Counts the start date as working day one.
  static DateTime calculateEndDate(DateTime startDate, {int workingDays = 10}) {
    if (workingDays < 1) {
      throw ArgumentError.value(workingDays, 'workingDays', 'Must be at least 1.');
    }
    if (!isWeekday(startDate)) {
      throw ArgumentError.value(startDate, 'startDate', 'Posting must start on a weekday.');
    }
    var result = DateTime(startDate.year, startDate.month, startDate.day);
    var count = 1;
    while (count < workingDays) {
      result = result.add(const Duration(days: 1));
      if (isWeekday(result)) count++;
    }
    return result;
  }

  static String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return day + '/' + month + '/' + date.year.toString();
  }

  static String fileDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return date.year.toString() + month + day;
  }
}