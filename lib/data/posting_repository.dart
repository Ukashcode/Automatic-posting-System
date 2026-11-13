import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../utils/posting_period.dart';

class PostingRepository {
  PostingRepository(this._database);

  final AppDatabase _database;
  static const int maxStudentsPerGroupPerUnit = 2;

  Stream<List<Student>> watchStudents() => (_database.select(
    _database.students,
  )..orderBy([(row) => OrderingTerm.asc(row.name)])).watch();

  Stream<List<PostingUnit>> watchUnits() => (_database.select(
    _database.postingUnits,
  )..orderBy([(row) => OrderingTerm.asc(row.sortOrder)])).watch();

  Stream<List<PostingUnit>> watchActiveUnits() => (_database.select(
    _database.postingUnits,
  )..where((row) => row.isActive)
    ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)])).watch();

  Stream<List<PostingView>> watchPostings() {
    final query = _database.select(_database.postings).join([
      innerJoin(_database.students, _database.students.id.equalsExp(_database.postings.studentId)),
      innerJoin(_database.postingUnits, _database.postingUnits.id.equalsExp(_database.postings.unitId)),
    ])..orderBy([OrderingTerm.desc(_database.postings.postedAt)]);
    return query.watch().map((rows) => rows.map((row) => PostingView(
      posting: row.readTable(_database.postings),
      student: row.readTable(_database.students),
      unit: row.readTable(_database.postingUnits),
    )).toList());
  }

  Future<List<PostingView>> getPostingsForExport() async {
    final query = _database.select(_database.postings).join([
      innerJoin(_database.students, _database.students.id.equalsExp(_database.postings.studentId)),
      innerJoin(_database.postingUnits, _database.postingUnits.id.equalsExp(_database.postings.unitId)),
    ])..orderBy([
      OrderingTerm.asc(_database.postingUnits.sortOrder),
      OrderingTerm.asc(_database.students.groupName),
      OrderingTerm.asc(_database.students.id),
    ]);
    final rows = await query.get();
    return rows.map((row) => PostingView(
      posting: row.readTable(_database.postings),
      student: row.readTable(_database.students),
      unit: row.readTable(_database.postingUnits),
    )).toList();
  }

  Future<void> ensureDefaultUnits() async {
    final rows = await _database.select(_database.postingUnits).get();
    if (rows.isNotEmpty) return;
    const names = ['Unit 1', 'Unit 2', 'Unit 3', 'Unit 4'];
    await _database.batch((batch) {
      batch.insertAll(_database.postingUnits, [
        for (var i = 0; i < names.length; i++)
          PostingUnitsCompanion.insert(name: names[i], sortOrder: Value(i)),
      ]);
    });
  }

  Future<int> addStudent({required String name, required String phoneNumber, required String groupName}) =>
      _database.into(_database.students).insert(StudentsCompanion.insert(
        name: name.trim(), phoneNumber: phoneNumber.trim(), groupName: groupName.trim(),
      ));

  Future<void> deleteStudent(int studentId) async {
    await _database.transaction(() async {
      await (_database.delete(_database.postings)..where((row) => row.studentId.equals(studentId))).go();
      await (_database.delete(_database.students)..where((row) => row.id.equals(studentId))).go();
    });
  }

  Future<void> saveUnit({int? id, required String name}) async {
    final value = name.trim();
    if (value.isEmpty) throw ArgumentError('Enter a posting-unit name.');
    final duplicate = await (_database.select(_database.postingUnits)..where((row) =>
      row.name.lower().equals(value.toLowerCase()) &
      (id == null ? const Constant(true) : row.id.isNotValue(id)),
    )).get();
    if (duplicate.isNotEmpty) throw StateError('A posting unit with this name already exists.');
    if (id == null) {
      final count = await _database.select(_database.postingUnits).get();
      await _database.into(_database.postingUnits).insert(PostingUnitsCompanion.insert(
        name: value, sortOrder: Value(count.length),
      ));
    } else {
      await (_database.update(_database.postingUnits)..where((row) => row.id.equals(id)))
          .write(PostingUnitsCompanion(name: Value(value)));
    }
  }

  Future<void> setUnitActive(int id, {required bool isActive}) async {
    final unit = await (_database.select(_database.postingUnits)..where((row) => row.id.equals(id))).getSingleOrNull();
    if (unit == null) throw StateError('Posting unit not found.');
    if (!isActive) {
      final active = await (_database.select(_database.postingUnits)..where((row) => row.isActive)).get();
      if (active.length == 1) throw StateError('At least one posting unit must remain active.');
    }
    await (_database.update(_database.postingUnits)..where((row) => row.id.equals(id)))
        .write(PostingUnitsCompanion(isActive: Value(isActive)));
  }

  Future<void> deleteUnit(int id) async {
    final used = await (_database.select(_database.postings)..where((row) => row.unitId.equals(id))).get();
    if (used.isNotEmpty) throw StateError('This unit has posting history. Mark it unavailable instead.');
    await (_database.delete(_database.postingUnits)..where((row) => row.id.equals(id))).go();
  }

  /// Builds a posting proposal without writing to the database or advancing students.
  Future<List<PostingPreviewItem>> buildPostingPreview() async {
    final students = await (_database.select(_database.students)..orderBy([(row) => OrderingTerm.asc(row.id)])).get();
    final units = await (_database.select(_database.postingUnits)
      ..where((row) => row.isActive)
      ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)])).get();
    if (students.isEmpty) throw StateError('Add students before generating postings.');
    if (units.isEmpty) throw StateError('Activate at least one posting unit before generating.');

    final byGroup = <String, List<Student>>{'A': [], 'B': []};
    for (final student in students) {
      final group = student.groupName.trim().toUpperCase();
      if (!byGroup.containsKey(group)) throw StateError('Student ' + student.name + ' has an unsupported group.');
      byGroup[group]!.add(student);
    }
    final existing = await _database.select(_database.postings).get();
    final previousByStudent = {for (final p in existing) p.studentId: p};
    for (final entry in byGroup.entries) {
      final needed = (entry.value.length + maxStudentsPerGroupPerUnit - 1) ~/ maxStudentsPerGroupPerUnit;
      if (needed > units.length) {
        final capacity = units.length * maxStudentsPerGroupPerUnit;
        throw StateError('Insufficient active units for Group ' + entry.key + '. ' +
          entry.value.length.toString() + ' students need at least ' + needed.toString() +
          ' units, but only ' + units.length.toString() + ' are active (capacity: ' + capacity.toString() + ').');
      }
    }

    final assignments = <int, int>{};
    final groupCounts = <String, Map<int, int>>{
      for (final group in ['A', 'B']) group: {for (final unit in units) unit.id: 0},
    };
    for (final group in ['A', 'B']) {
      final groupStudents = byGroup[group]!;
      final counts = groupCounts[group]!;
      for (final student in groupStudents) {
        final previous = previousByStudent[student.id];
        final previousIndex = previous == null ? -1 : units.indexWhere((unit) => unit.id == previous.unitId);
        final startIndex = previousIndex < 0 ? 0 : (previousIndex + 1) % units.length;
        var selectedIndex = -1;
        var selectedCount = maxStudentsPerGroupPerUnit + 1;
        for (var offset = 0; offset < units.length; offset++) {
          final index = (startIndex + offset) % units.length;
          final count = counts[units[index].id]!;
          if (count < maxStudentsPerGroupPerUnit && count < selectedCount) {
            selectedIndex = index;
            selectedCount = count;
          }
        }
        if (selectedIndex < 0) throw StateError('No remaining capacity for Group ' + group + '.');
        final unitId = units[selectedIndex].id;
        assignments[student.id] = unitId;
        counts[unitId] = counts[unitId]! + 1;
      }
    }

    // Retain the existing odd-group overlap preference where capacity allows.
    for (final group in ['A', 'B']) {
      final counts = groupCounts[group]!;
      final other = groupCounts[group == 'A' ? 'B' : 'A']!;
      final singletons = counts.entries.where((entry) => entry.value == 1).toList();
      if (singletons.isEmpty) continue;
      final singletonId = singletons.first.key;
      final candidates = units.where((unit) => unit.id != singletonId && counts[unit.id] == 2).toList();
      if (candidates.isEmpty) continue;
      candidates.sort((a, b) => (other[b.id]! > 0 ? 1 : 0).compareTo(other[a.id]! > 0 ? 1 : 0));
      final target = candidates.first;
      final move = byGroup[group]!.lastWhere((student) => assignments[student.id] == target.id);
      assignments[move.id] = singletonId;
      counts[singletonId] = counts[singletonId]! + 1;
      counts[target.id] = counts[target.id]! - 1;
    }
    return [for (final student in students)
      PostingPreviewItem(student: student, unit: units.firstWhere((unit) => unit.id == assignments[student.id]))];
  }

  /// Saves exactly the preview the coordinator reviewed. It rejects stale previews.
  Future<int> confirmPostingPreview({
    required List<PostingPreviewItem> preview,
    required DateTime periodStartDate,
    required DateTime periodEndDate,
  }) async {
    if (preview.isEmpty) throw StateError('There are no students to confirm.');
    if (!PostingPeriod.isWeekday(periodStartDate)) {
      throw ArgumentError('Posting must start on a weekday.');
    }
    final currentStudents = await (_database.select(_database.students)..orderBy([(row) => OrderingTerm.asc(row.id)])).get();
    if (currentStudents.length != preview.length) throw StateError('Student records changed. Create the preview again before confirming.');
    for (var i = 0; i < currentStudents.length; i++) {
      final old = preview[i].student;
      final now = currentStudents[i];
      if (old.id != now.id || old.name != now.name || old.phoneNumber != now.phoneNumber || old.groupName != now.groupName) {
        throw StateError('Student records changed. Create the preview again before confirming.');
      }
    }
    final unitRows = await _database.select(_database.postingUnits).get();
    final unitsById = {for (final unit in unitRows) unit.id: unit};
    for (final item in preview) {
      final latestUnit = unitsById[item.unit.id];
      if (latestUnit == null || !latestUnit.isActive || latestUnit.name != item.unit.name) {
        throw StateError('Posting units changed. Create the preview again before confirming.');
      }
    }
    final calculatedEnd = PostingPeriod.calculateEndDate(periodStartDate);
    if (periodEndDate.year != calculatedEnd.year || periodEndDate.month != calculatedEnd.month || periodEndDate.day != calculatedEnd.day) {
      throw ArgumentError('The end date must be the tenth working day after the selected start date.');
    }
    final existing = await _database.select(_database.postings).get();
    final existingByStudent = {for (final row in existing) row.studentId: row};
    final batchId = DateTime.now().microsecondsSinceEpoch;
    final postedAt = DateTime.now();
    await _database.transaction(() async {
      for (final item in preview) {
        final previous = existingByStudent[item.student.id];
        if (previous == null) {
          await _database.into(_database.postings).insert(PostingsCompanion.insert(
            studentId: item.student.id, unitId: item.unit.id, batchId: batchId,
            postedAt: Value(postedAt), periodStartDate: Value(periodStartDate), periodEndDate: Value(periodEndDate),
          ));
        } else {
          await (_database.update(_database.postings)..where((row) => row.id.equals(previous.id))).write(PostingsCompanion(
            unitId: Value(item.unit.id), batchId: Value(batchId), postedAt: Value(postedAt),
            periodStartDate: Value(periodStartDate), periodEndDate: Value(periodEndDate),
          ));
        }
      }
    });
    return preview.length;
  }

  Future<int> generateBalancedPostings({String? scheduleOfDuty}) async {
    final preview = await buildPostingPreview();
    final existing = await _database.select(_database.postings).get();
    final existingByStudent = {for (final p in existing) p.studentId: p};
    final batchId = DateTime.now().microsecondsSinceEpoch;
    await _database.transaction(() async {
      for (final item in preview) {
        final previous = existingByStudent[item.student.id];
        final savedDuty = scheduleOfDuty?.trim().isNotEmpty == true ? scheduleOfDuty!.trim() : previous?.scheduleOfDuty;
        if (previous == null) {
          await _database.into(_database.postings).insert(PostingsCompanion.insert(
            studentId: item.student.id, unitId: item.unit.id, batchId: batchId, scheduleOfDuty: Value(savedDuty),
          ));
        } else {
          await (_database.update(_database.postings)..where((row) => row.id.equals(previous.id))).write(
            PostingsCompanion(unitId: Value(item.unit.id), batchId: Value(batchId), scheduleOfDuty: Value(savedDuty)),
          );
        }
      }
    });
    return preview.length;
  }

}}

class PostingPreviewItem {
  const PostingPreviewItem({required this.student, required this.unit});
  final Student student;
  final PostingUnit unit;
}

class PostingView {
  const PostingView({required this.posting, required this.student, required this.unit});
  final Posting posting;
  final Student student;
  final PostingUnit unit;
}