import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:akth_posting_web/data/posting_repository.dart';
import 'package:akth_posting_web/database/app_database.dart';
import 'package:akth_posting_web/pages/record_page.dart';

class _FakePostingRepository extends PostingRepository {
  _FakePostingRepository(super.database);

  final List<Map<String, String>> addedStudents = [];

  @override
  Stream<List<Student>> watchStudents() => Stream.value([]);

  @override
  Future<int> addStudent({
    required String name,
    required String phoneNumber,
    required String groupName,
  }) async {
    addedStudents.add({
      'name': name,
      'phoneNumber': phoneNumber,
      'groupName': groupName,
    });
    return addedStudents.length;
  }

  @override
  Future<void> deleteStudent(int studentId) async {}
}

void main() {
  late AppDatabase database;
  late _FakePostingRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = _FakePostingRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> pumpRecord(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Record(repository: repository)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows only the two supported student groups', (tester) async {
    await pumpRecord(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(DropdownButtonFormField<String>),
        matching: find.byIcon(Icons.arrow_drop_down),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Group A (Mon/Tue)'), findsOneWidget);
    expect(find.text('Group B (Wed/Thu)'), findsOneWidget);
  });

  testWidgets('requires a group before adding a student', (tester) async {
    await pumpRecord(tester);

    await tester.tap(find.text('Add Student'));
    await tester.pumpAndSettle();

    expect(find.text('Select a group'), findsOneWidget);
    expect(repository.addedStudents, isEmpty);
  });

  testWidgets('saves the selected group value', (tester) async {
    await pumpRecord(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'Test Student');
    await tester.enterText(find.byType(TextFormField).at(1), '08000000000');

    await tester.tap(
      find.descendant(
        of: find.byType(DropdownButtonFormField<String>),
        matching: find.byIcon(Icons.arrow_drop_down),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Group B (Wed/Thu)').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Student'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(repository.addedStudents, hasLength(1));
    expect(repository.addedStudents.single['name'], 'Test Student');
    expect(repository.addedStudents.single['phoneNumber'], '08000000000');
    expect(repository.addedStudents.single['groupName'], 'B');
  });
}
