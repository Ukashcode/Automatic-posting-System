import 'package:drift/drift.dart';

import '../database/app_database.dart';

class PostingRepository {
  PostingRepository(this._database);

  final AppDatabase _database;

  Stream<List<Student>> watchStudents() => (_database.select(
    _database.students,
  )..orderBy([(row) => OrderingTerm.asc(row.name)])).watch();

  Stream<List<PostingUnit>> watchUnits() => (_database.select(
    _database.postingUnits,
  )..orderBy([(row) => OrderingTerm.asc(row.sortOrder)])).watch();

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
          OrderingTerm.asc(_database.students.name),
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

  Future<void> saveUnit({int? id, required String name}) async {
    final value = name.trim();
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

  Future<void> deleteUnit(int id) async {
    final used = await (_database.select(
      _database.postings,
    )..where((row) => row.unitId.equals(id))).get();
    if (used.isNotEmpty) {
      throw StateError('This unit has posting history and cannot be deleted.');
    }
    await (_database.delete(
      _database.postingUnits,
    )..where((row) => row.id.equals(id))).go();
  }

  Future<int> generateBalancedPostings({String? scheduleOfDuty}) async {
    final students = await (_database.select(
      _database.students,
    )..orderBy([(row) => OrderingTerm.asc(row.id)])).get();
    final units = await (_database.select(
      _database.postingUnits,
    )..orderBy([(row) => OrderingTerm.asc(row.sortOrder)])).get();
    if (students.isEmpty)
      throw StateError('Add students before generating postings.');
    if (units.isEmpty) throw StateError('Add at least one posting unit first.');

    final existing = await _database.select(_database.postings).get();
    final existingByStudent = {
      for (final posting in existing) posting.studentId: posting,
    };
    final batchId = DateTime.now().microsecondsSinceEpoch;
    final assignmentCounts = <int, int>{for (final unit in units) unit.id: 0};
    final nextUnitByStudent = <int, int>{};

    // Advance existing students to the next configured unit whenever the
    // user clicks Generate Posting. This is click-based, not date-based.
    for (final student in students) {
      final previous = existingByStudent[student.id];
      if (previous == null) continue;

      final previousIndex = units.indexWhere(
        (unit) => unit.id == previous.unitId,
      );
      final nextIndex = previousIndex < 0
          ? 0
          : (previousIndex + 1) % units.length;
      final nextUnit = units[nextIndex];
      nextUnitByStudent[student.id] = nextUnit.id;
      assignmentCounts.update(nextUnit.id, (count) => count + 1);
    }

    // Put newly registered students in the least-populated destination.
    for (final student in students) {
      if (existingByStudent.containsKey(student.id)) continue;
      var selectedUnit = units.first;
      for (final unit in units.skip(1)) {
        if (assignmentCounts[unit.id]! < assignmentCounts[selectedUnit.id]!) {
          selectedUnit = unit;
        }
      }
      nextUnitByStudent[student.id] = selectedUnit.id;
      assignmentCounts.update(selectedUnit.id, (count) => count + 1);
    }

    final postedAt = DateTime.now();
    await _database.transaction(() async {
      for (final student in students) {
        final previous = existingByStudent[student.id];
        final nextUnitId = nextUnitByStudent[student.id]!;
        final duty = scheduleOfDuty?.trim();
        final savedDuty = duty == null || duty.isEmpty
            ? previous?.scheduleOfDuty
            : duty;

        if (previous == null) {
          await _database
              .into(_database.postings)
              .insert(
                PostingsCompanion.insert(
                  studentId: student.id,
                  unitId: nextUnitId,
                  batchId: batchId,
                  scheduleOfDuty: Value(savedDuty),
                  postedAt: Value(postedAt),
                ),
              );
        } else {
          await (_database.update(
            _database.postings,
          )..where((posting) => posting.id.equals(previous.id))).write(
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
