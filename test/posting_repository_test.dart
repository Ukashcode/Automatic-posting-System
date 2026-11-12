import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:akth_posting_web/data/posting_repository.dart';
import 'package:akth_posting_web/database/app_database.dart';

void main() {
  late AppDatabase database;
  late PostingRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = PostingRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> addUnits(int count) async {
    for (var i = 0; i < count; i++) {
      await repository.saveUnit(name: 'Unit ${i + 1}');
    }
  }

  Future<void> addStudents(String group, int count) async {
    for (var i = 0; i < count; i++) {
      await repository.addStudent(
        name: '$group Student ${i + 1}',
        phoneNumber: '0800000000$i',
        groupName: group,
      );
    }
  }

  test('allocates each group independently and respects two-per-unit limit', () async {
    await addUnits(2);
    await addStudents('A', 3);
    await addStudents('B', 2);

    expect(await repository.generateBalancedPostings(), 5);

    final postings = await repository.getPostingsForExport();
    final counts = <String, Map<String, int>>{};
    for (final item in postings) {
      counts.putIfAbsent(item.unit.name, () => {'A': 0, 'B': 0});
      counts[item.unit.name]![item.student.groupName] =
          counts[item.unit.name]![item.student.groupName]! + 1;
    }

    for (final unitCounts in counts.values) {
      expect(unitCounts['A']!, lessThanOrEqualTo(2));
      expect(unitCounts['B']!, lessThanOrEqualTo(2));
    }

    // The odd Group A student is placed in a unit also used by Group B.
    final groupAUnits = postings
        .where((item) => item.student.groupName == 'A')
        .map((item) => item.unit.name)
        .toSet();
    final groupBUnits = postings
        .where((item) => item.student.groupName == 'B')
        .map((item) => item.unit.name)
        .toSet();
    expect(groupAUnits.intersection(groupBUnits), isNotEmpty);
  });

  test('blocks generation when active unit capacity is insufficient', () async {
    await addUnits(1);
    await addStudents('A', 3);

    await expectLater(
      repository.generateBalancedPostings(),
      throwsA(isA<StateError>()),
    );

    expect(await repository.getPostingsForExport(), isEmpty);
  });

  test('unavailable units are excluded from capacity and assignment', () async {
    await addUnits(2);
    final units = await database.select(database.postingUnits).get();
    await repository.setUnitActive(units.first.id, isActive: false);
    await addStudents('A', 3);

    await expectLater(
      repository.generateBalancedPostings(),
      throwsA(isA<StateError>()),
    );

    expect(await repository.getPostingsForExport(), isEmpty);
  });
}
