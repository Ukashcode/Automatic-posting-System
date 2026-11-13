import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:akth_posting_web/data/posting_repository.dart';
import 'package:akth_posting_web/database/app_database.dart';

void main() {
  test('v4 migration preserves students and postings and allows empty details', () async {
    final database = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (rawDatabase) {
          rawDatabase.execute('PRAGMA foreign_keys = ON');

          rawDatabase.execute('''
            CREATE TABLE students (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL CHECK (length(name) >= 1 AND length(name) <= 120),
              phone_number TEXT NOT NULL CHECK (length(phone_number) >= 1 AND length(phone_number) <= 30),
              group_name TEXT NOT NULL CHECK (length(group_name) >= 1 AND length(group_name) <= 80),
              created_at INTEGER NOT NULL
            )
          ''');

          rawDatabase.execute('''
            CREATE TABLE posting_units (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL UNIQUE CHECK (length(name) >= 1 AND length(name) <= 120),
              sort_order INTEGER NOT NULL DEFAULT 0,
              is_active INTEGER NOT NULL DEFAULT 1
            )
          ''');

          rawDatabase.execute('''
            CREATE TABLE postings (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              student_id INTEGER NOT NULL REFERENCES students (id) UNIQUE,
              unit_id INTEGER NOT NULL REFERENCES posting_units (id),
              batch_id INTEGER NOT NULL,
              schedule_of_duty TEXT,
              posted_at INTEGER NOT NULL,
              period_start_date INTEGER,
              period_end_date INTEGER
            )
          ''');

          rawDatabase.execute(
            "INSERT INTO posting_units (id, name, sort_order, is_active) VALUES (1, 'Unit 1', 0, 1)",
          );
          rawDatabase.execute(
            "INSERT INTO students (id, name, phone_number, group_name, created_at) VALUES (1, 'Existing student', '08012345678', 'A', 0)",
          );
          rawDatabase.execute(
            'INSERT INTO postings (id, student_id, unit_id, batch_id, posted_at) VALUES (1, 1, 1, 100, 0)',
          );
          rawDatabase.execute('PRAGMA user_version = 4');
        },
      ),
    );

    addTearDown(database.close);

    final repository = PostingRepository(database);
    final existingStudents = await database.select(database.students).get();
    expect(existingStudents, hasLength(1));
    expect(existingStudents.single.name, 'Existing student');

    final existingPostings = await repository.getPostingsForExport();
    expect(existingPostings, hasLength(1));
    expect(existingPostings.single.student.phoneNumber, '08012345678');
    expect(existingPostings.single.unit.name, 'Unit 1');

    final newStudentId = await repository.addStudent(
      name: '   ',
      phoneNumber: '   ',
      groupName: 'B',
    );
    final newStudent = await (database.select(database.students)
          ..where((row) => row.id.equals(newStudentId)))
        .getSingle();

    expect(newStudent.name, '');
    expect(newStudent.phoneNumber, '');

    final foreignKeyViolations = await database
        .customSelect('PRAGMA foreign_key_check')
        .get();
    expect(foreignKeyViolations, isEmpty);
  });
}
