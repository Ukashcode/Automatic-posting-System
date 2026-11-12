import 'package:drift/drift.dart';

import '../database/app_database.dart';

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
      innerJoin(
        _database.students,
        _database.students.id.equalsExp(_database.postings.studentId),
      ),
      innerJoin(
        _database.postingUnits,
        _database.postingUnits.id.equalsExp(_database.postings.unitId),
      ),
    ])..orderBy([OrderingTerm.desc(_database.postings.postedAt)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => PostingView(
              posting: row.readTable(_database.postings),
              student: row.readTable(_database.students),
              unit: row.readTable(_database.postingUnits),
            ),
          )
          .toList(),
    );
  }

  Future<List<PostingView>> getPostingsForExport() async {
    final query =
        _database.select(_database.postings).join([
          innerJoin(
            _database.students,
            _database.students.id.equalsExp(_database.postings.studentId),
          ),
          innerJoin(
            _database.postingUnits,
            _database.postingUnits.id.equalsExp(_database.postings.unitId),
          ),
        ])..orderBy([
          OrderingTerm.asc(_database.postingUnits.sortOrder),
          OrderingTerm.asc(_database.students.groupName),
          OrderingTerm.asc(_database.students.id),
        ]);

    final rows = await query.get();
    return rows
        .map(
          (row) => PostingView(
            posting: row.readTable(_database.postings),
            student: row.readTable(_database.students),
            unit: row.readTable(_database.postingUnits),
          ),
        )
        .toList();
  }

  Future<void> ensureDefaultUnits() async {
    if (await _database
        .select(_database.postingUnits)
        .get()
        .then((rows) => rows.isNotEmpty)) {
      return;
    }
    const names = ['Unit 1', 'Unit 2', 'Unit 3', 'Unit 4'];
    await _database.batch((batch) {
      batch.insertAll(_database.postingUnits, [
        for (var i = 0; i < names.length; i++)
          PostingUnitsCompanion.insert(name: names[i], sortOrder: Value(i)),
      ]);
    });
  }

  Future<int> addStudent({
    required String name,
    required String phoneNumber,
    required String groupName,
  }) => _database
      .into(_database.students)
      .insert(
        StudentsCompanion.insert(
          name: name.trim(),
          phoneNumber: phoneNumber.trim(),
          groupName: groupName.trim(),
        ),
      );

  Future<void> deleteStudent(int studentId) async {
    await _database.transaction(() async {
      await (_database.delete(
        _database.postings,
      )..where((posting) => posting.studentId.equals(studentId))).go();
      await (_database.delete(
        _database.students,
      )..where((student) => student.id.equals(studentId))).go();
    });
  }

  Future<void> saveUnit({int? id, required String name}) async {
    final value = name.trim();
    if (value.isEmpty) throw ArgumentError('Enter a posting-unit name.');

    final duplicate = await (_database.select(_database.postingUnits)
          ..where(
            (row) =>
                row.name.lower().equals(value.toLowerCase()) &
                (id == null ? const Constant(true) : row.id.isNotValue(id)),
          ))
        .get();
    if (duplicate.isNotEmpty) {
      throw StateError('A posting unit with this name already exists.');
    }

    if (id == null) {
      final count = await _database.select(_database.postingUnits).get();
      await _database
          .into(_database.postingUnits)
          .insert(
            PostingUnitsCompanion.insert(
              name: value,
              sortOrder: Value(count.length),
            ),
          );
    } else {
      await (_database.update(_database.postingUnits)
            ..where((row) => row.id.equals(id)))
          .write(PostingUnitsCompanion(name: Value(value)));
    }
  }

  Future<void> setUnitActive(int id, {required bool isActive}) async {
    final unit = await (_database.select(_database.postingUnits)
          ..where((row) => row.id.equals(id)))
        .getSingleOrNull();
    if (unit == null) throw StateError('Posting unit not found.');

    if (isActive == false) {
      final activeUnits = await (_database.select(_database.postingUnits)
            ..where((row) => row.isActive))
          .get();
      if (activeUnits.length == 1) {
        throw StateError('At least one posting unit must remain active.');
      }
    }

    await (_database.update(_database.postingUnits)
          ..where((row) => row.id.equals(id)))
        .write(PostingUnitsCompanion(isActive: Value(isActive)));
  }

  Future<void> deleteUnit(int id) async {
    final used = await (_database.select(
      _database.postings,
    )..where((row) => row.unitId.equals(id))).get();
    if (used.isNotEmpty) {
      throw StateError(
        'This unit has posting history. Mark it unavailable instead.',
      );
    }
    await (_database.delete(
      _database.postingUnits,
    )..where((row) => row.id.equals(id))).go();
  }

  Future<int> generateBalancedPostings({String? scheduleOfDuty}) async {
    final students = await (_database.select(
      _database.students,
    )..orderBy([(row) => OrderingTerm.asc(row.id)])).get();
    final units = await (_database.select(_database.postingUnits)
          ..where((row) => row.isActive)
          ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]))
        .get();

    if (students.isEmpty) {
      throw StateError('Add students before generating postings.');
    }
    if (units.isEmpty) {
      throw StateError('Activate at least one posting unit before generating.');
    }

    final studentsByGroup = <String, List<Student>>{'A': [], 'B': []};
    for (final student in students) {
      final group = student.groupName.trim().toUpperCase();
      if (!studentsByGroup.containsKey(group)) {
        throw StateError(
          'Student ${student.name} has an unsupported group "${student.groupName}".',
        );
      }
      studentsByGroup[group]!.add(student);
    }

    final existing = await _database.select(_database.postings).get();
    final existingByStudent = {
      for (final posting in existing) posting.studentId: posting,
    };

    final requiredUnitsByGroup = {
      for (final entry in studentsByGroup.entries)
        entry.key: (entry.value.length + maxStudentsPerGroupPerUnit - 1) ~/
            maxStudentsPerGroupPerUnit,
    };
    for (final entry in requiredUnitsByGroup.entries) {
      if (entry.value > units.length) {
        final studentCount = studentsByGroup[entry.key]!.length;
        final capacity = units.length * maxStudentsPerGroupPerUnit;
        throw StateError(
          'Insufficient active posting units for Group ${entry.key}. '
          '$studentCount students need at least ${entry.value} units, '
          'but only ${units.length} are active (capacity: $capacity). '
          'Activate or add another posting unit.',
        );
      }
    }

    final assignments = <int, int>{};
    final groupCounts = <String, Map<int, int>>{
      for (final group in ['A', 'B'])
        group: {for (final unit in units) unit.id: 0},
    };

    for (final group in ['A', 'B']) {
      final groupStudents = studentsByGroup[group]!;
      final counts = groupCounts[group]!;
      for (final student in groupStudents) {
        final previous = existingByStudent[student.id];
        final previousIndex = previous == null
            ? -1
            : units.indexWhere((unit) => unit.id == previous.unitId);
        final startIndex = previousIndex < 0
            ? 0
            : (previousIndex + 1) % units.length;

        var selectedUnitIndex = -1;
        var selectedCount = maxStudentsPerGroupPerUnit + 1;
        for (var offset = 0; offset < units.length; offset++) {
          final index = (startIndex + offset) % units.length;
          final count = counts[units[index].id]!;
          if (count < maxStudentsPerGroupPerUnit && count < selectedCount) {
            selectedUnitIndex = index;
            selectedCount = count;
          }
        }

        if (selectedUnitIndex < 0) {
          throw StateError(
            'No remaining capacity for Group $group. Review active posting units.',
          );
        }

        final unitId = units[selectedUnitIndex].id;
        assignments[student.id] = unitId;
        counts.update(unitId, (count) => count + 1);
      }
    }

    // When a group has one single-student unit, move one student from a
    // paired unit into it. This keeps the group count valid while allowing
    // the singleton assignment to share a destination with the other group.
    for (final group in ['A', 'B']) {
      final counts = groupCounts[group]!;
      final otherCounts = groupCounts[group == 'A' ? 'B' : 'A']!;
      final singletonEntry = counts.entries
          .where((entry) => entry.value == 1)
          .firstOrNull;
      if (singletonEntry == null) continue;

      final singletonUnitId = singletonEntry.key;
      final targetUnit = units.firstWhere(
        (unit) =>
            unit.id != singletonUnitId &&
            counts[unit.id] == 2 &&
            otherCounts[unit.id]! > 0,
        orElse: () => units.firstWhere(
          (unit) => unit.id != singletonUnitId && counts[unit.id] == 2,
          orElse: () => units.first,
        ),
      );
      if (targetUnit.id == singletonUnitId ||
          counts[targetUnit.id] != 2) {
        continue;
      }

      final studentToMove = studentsByGroup[group]!.lastWhere(
        (student) => assignments[student.id] == targetUnit.id,
      );
      assignments[studentToMove.id] = singletonUnitId;
      counts[singletonUnitId] = counts[singletonUnitId]! + 1;
      counts[targetUnit.id] = counts[targetUnit.id]! - 1;
    }

    final batchId = DateTime.now().microsecondsSinceEpoch;
    final postedAt = DateTime.now();
    final duty = scheduleOfDuty?.trim();

    await _database.transaction(() async {
      for (final student in students) {
        final previous = existingByStudent[student.id];
        final savedDuty = duty == null || duty.isEmpty
            ? previous?.scheduleOfDuty
            : duty;
        final nextUnitId = assignments[student.id]!;

        if (previous == null) {
          await _database.into(_database.postings).insert(
                PostingsCompanion.insert(
                  studentId: student.id,
                  unitId: nextUnitId,
                  batchId: batchId,
                  scheduleOfDuty: Value(savedDuty),
                  postedAt: Value(postedAt),
                ),
              );
        } else {
          await (_database.update(_database.postings)
                ..where((posting) => posting.id.equals(previous.id)))
              .write(
            PostingsCompanion(
              unitId: Value(nextUnitId),
              batchId: Value(batchId),
              scheduleOfDuty: Value(savedDuty),
              postedAt: Value(postedAt),
            ),
          );
        }
      }
    });
    return students.length;
  }
}

class PostingView {
  const PostingView({
    required this.posting,
    required this.student,
    required this.unit,
  });

  final Posting posting;
  final Student student;
  final PostingUnit unit;
}
