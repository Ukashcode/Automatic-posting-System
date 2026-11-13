# AKTH SIWES Posting Algorithm

This document describes the current group-aware posting behaviour on the dynamic posting-management feature branch.

## Rules

1. Students are processed in the order they were registered.
2. Only active posting units are eligible for a new generation.
3. Group A and Group B are assigned independently.
4. A unit can receive at most two students from Group A and two from Group B in one generation.
5. Required capacity is calculated separately for each group: `ceil(group student count / 2)` active units are needed.
6. If either group needs more units than are active, generation stops before changing any assignment and explains the shortage.
7. If a group has one single-student unit, the allocator tries to move one student from a paired unit so the single-student assignment shares a destination with the other group where possible.
8. Existing students advance from their previous unit to the next active unit in configured order. If their previous unit is no longer active, they restart from the first active unit.
9. New students are distributed across the active units while respecting the per-group limit.
10. All current assignments for a generation are saved in one database transaction.

## Unit availability

Posting units have an `isActive` flag. Existing databases are migrated so previously registered units remain active by default.

- Active: eligible for future generations.
- Inactive: unavailable for future generations, but retained in the database.
- Delete: allowed only when the unit has no posting records. Units with posting records should be marked inactive instead so the unit name remains available to existing assignments.

The dashboard's available-unit count includes active units only.

## Capacity examples

With 11 active units, each group can accommodate up to 22 students. With 12 active units, each group can accommodate up to 24 students.

For 23 Group A students and 22 Group B students, 12 active units are required. The maximum remains two students per group per unit.

## Persistence and history limitation

The current database stores one current assignment per student. Each generation updates that assignment and its batch identifier; it does not yet retain a separate immutable record for every historical generation. Unit deactivation preserves the unit row and current assignments, but a full generation-history feature is still a separate planned change.

## Implementation

- Database schema and migration: `lib/database/app_database.dart`
- Assignment and capacity logic: `lib/data/posting_repository.dart`
- Unit availability controls: `lib/pages/units_page.dart`
- Active-unit dashboard count: `lib/pages/dashboard_page.dart`
- Repository tests: `test/posting_repository_test.dart`

After pulling this branch, regenerate Drift's generated file before running the tests:

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test
```


## Preview, confirmation, and export workflow

The dashboard lets the coordinator select a weekday start date. The end date is calculated as the tenth working day, counting the start date and skipping Saturday and Sunday. Public holidays are not currently excluded.

Selecting **Preview Posting** runs the allocation algorithm without writing to the database. The preview displays the proposed assignments and effective dates. It does not advance students or change their saved postings.

When the coordinator confirms the preview, the application verifies that the student and posting-unit records have not changed, then saves the reviewed assignments and period dates in one database transaction.

After confirmation, the same reviewed assignment list can be exported separately as:
- **Excel:** an editable workbook for administrative use. Changes made to the downloaded workbook do not update the application database or the PDF.
- **PDF:** a print-ready document with the Digital Health Department heading, effective dates, and student posting table.

The current posting period dates are stored on each student's current posting. This is not a posting-history feature; a later confirmed generation replaces the student's current assignment and period.
