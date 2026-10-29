# AKTH SIWES Posting Algorithm

This file explains how **Generate Posting** assigns SIWES students to posting units in the AKTH web application.

## Goal

Distribute students as evenly as possible across the available units, while advancing existing students when the user starts another generation. The advance happens on each button click; it is not tied to a two-week calendar.

## Rules

1. The app loads students in the order they were added and units in their configured order.
2. It checks that there is at least one student and one unit.
3. For each student with an existing assignment, it advances the student to the next unit in the configured order. The last unit wraps around to the first.
4. For each newly registered student, it chooses the unit with the fewest planned assignments in this generation. Ties go to the first unit in the configured order.
5. It updates the counts as new students are assigned.
6. It saves all changes in one transaction and downloads an Excel file containing every student's current assignment.

The initial unit list contains **Unit 1**, **Unit 2**, **Unit 3**, and **Unit 4**. Unit names can be changed, and additional units can be added. Renaming a unit does not change its order. New units are appended after the current units.

## Worked example

Suppose there are four units in the order Unit 1, Unit 2, Unit 3, Unit 4. A student currently assigned to Unit 2 moves to Unit 3 on the next click. A student assigned to Unit 4 moves to Unit 1. After existing students advance, newly registered students are placed in whichever destination has the fewest assignments.

For example, if the planned destination totals for new students are:

| Unit | Planned assignments |
| --- | ---: |
| Unit 1 | 3 |
| Unit 2 | 2 |
| Unit 3 | 2 |
| Unit 4 | 1 |

The next new student goes to Unit 4 because it has the fewest planned assignments. Its total becomes 2. The next new student sees Units 2, 3, and 4 tied at 2, so Unit 2 is selected because it comes first in the configured order. Counts update after every assignment.

## Persistence and repeat runs

- Assignments are written to SQLite through Drift.
- Each generation run replaces the current unit assignment for existing students and stores a new batch identifier and posting time.
- All assignments from one run are saved in a database transaction. If a write fails, the transaction prevents a partially saved batch.
- Each student has one current posting. Re-running generation advances current postings rather than creating duplicate rows.
- A unit with a current posting cannot be deleted.
- An optional schedule-of-duty value can be stored with an assignment; the current Generate Posting screen does not ask for one.

## What affects the assignment

Existing students' next assignments depend on their current unit and the configured order. New students' assignments depend on the planned unit counts and unit order. The algorithm does not use a student's group, phone number, preferences, qualifications, or unit capacity. It has no time-based two-week schedule. Each click advances assignments to the next unit.

## Implementation

The assignment logic is in `lib/data/posting_repository.dart`, in `generateBalancedPostings`. The SQLite tables are declared in `lib/database/app_database.dart`. The Dashboard calls the repository when the user selects **Generate Posting**.
