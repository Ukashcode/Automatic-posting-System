import 'package:flutter_test/flutter_test.dart';

import 'package:akth_posting_web/utils/posting_period.dart';

void main() {
  test('counts ten working days and skips weekends', () {
    final start = DateTime(2026, 11, 2); // Monday
    final end = PostingPeriod.calculateEndDate(start);
    expect(end, DateTime(2026, 11, 13)); // Friday
  });

  test('counts the selected Friday as working day one', () {
    final end = PostingPeriod.calculateEndDate(DateTime(2026, 11, 6));
    expect(end, DateTime(2026, 11, 19));
  });

  test('rejects a weekend start date', () {
    expect(
      () => PostingPeriod.calculateEndDate(DateTime(2026, 11, 7)),
      throwsArgumentError,
    );
  });
}