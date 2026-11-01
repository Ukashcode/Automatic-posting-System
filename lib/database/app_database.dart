import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class Students extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get phoneNumber => text().withLength(min: 1, max: 30)();
  TextColumn get groupName => text().withLength(min: 1, max: 80)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class PostingUnits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120).unique()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class Postings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get studentId => integer().references(Students, #id).unique()();
  IntColumn get unitId => integer().references(PostingUnits, #id)();
  IntColumn get batchId => integer()();
  TextColumn get scheduleOfDuty => text().nullable()();
  DateTimeColumn get postedAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [Students, PostingUnits, Postings])
class AppDatabase extends _$AppDatabase {
  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  AppDatabase()
    : super(
        driftDatabase(
          name: 'akth_posting',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      );

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) await migrator.createAll();
    },
  );
}
