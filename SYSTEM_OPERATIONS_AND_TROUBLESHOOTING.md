# AKTH SIWES Posting System
# Operations, Troubleshooting, Database, Algorithm and Git Guide

**Purpose:** A practical handover and recovery guide for the current application. It explains what the code actually does, what can fail, what an operator can and cannot do in the current UI, and how a developer should investigate and repair the project.

**Code baseline reviewed:** GitHub `main` at commit `3a64cdc` (13 November 2026).

> **Important:** This guide describes the implementation currently present in the repository. It distinguishes implemented behaviour from limitations and future recommendations. Passing tests means the tested cases passed; it does not prove that every browser, device, data size, network condition, or long-term use case will work without problems.

---

## 1. Read this first

The current system is a **local-first Flutter web application**. It uses Drift to manage a SQLite database running in the browser through SQLite WASM and the Drift worker.

It is not currently a central multi-user server application:

- Student, posting-unit and posting data are stored in the browser database for the application's browser origin.
- Two people using different computers or browser profiles do not automatically share one database.
- There is no application login or role-based access control in the current UI. The Logout item was removed and authentication has not been implemented.
- There is no in-app database backup/restore screen.
- An exported Excel or PDF file is an output document, not a complete backup of the database.

**Protect the browser data.** Do not clear browser site data, IndexedDB, local storage, or the browser profile as a troubleshooting experiment. Doing so can remove the local application database. Opening the app on a different origin (for example, a different localhost port) can make the application appear empty because that origin has separate browser storage.

### Fast commands when something is wrong

Run these from the project folder:

```powershell
git status
flutter pub get
dart run build_runner build
flutter analyze
flutter test
flutter build web
```

Do not run every command blindly. Use the troubleshooting sections below to identify which step addresses the actual failure. If you changed a Drift table, regenerate the Drift code before analysis and tests.

---

## 2. Application structure: where to look first

| Area | File | Responsibility |
|---|---|---|
| Application startup | `lib/main.dart` | Initializes Flutter, creates default units if the unit table is empty, then launches the app |
| Shared dependencies | `lib/data/app_dependencies.dart` | Creates the database and repository instances |
| Database schema and migrations | `lib/database/app_database.dart` | Defines tables, schema version and upgrade steps |
| Generated database API | `lib/database/app_database.g.dart` | Drift-generated table classes, data classes and companions; do not hand-edit |
| Main data and posting rules | `lib/data/posting_repository.dart` | Adds/deletes students, manages units, calculates previews, confirms assignments |
| Student screen | `lib/pages/record_page.dart` | Student registration and deletion UI |
| Unit screen | `lib/pages/units_page.dart` | Add, rename, activate/deactivate and delete posting units |
| Dashboard | `lib/pages/dashboard_page.dart` | Counts, start-date selection, navigation to preview |
| Preview and confirmation | `lib/pages/posting_preview_page.dart` | Loads a proposal, confirms it and exposes export buttons |
| Posting dates | `lib/utils/posting_period.dart` | Weekday checks and ten-working-day end-date calculation |
| Excel output | `lib/services/posting_excel_export_service.dart` | Builds an XLSX workbook and triggers a browser download |
| PDF output | `lib/services/posting_pdf_export_service.dart` | Builds a PDF and triggers a browser download |
| Posting tests | `test/posting_repository_test.dart` | Tests allocation, capacity, preview, confirmation and empty student details |
| Date tests | `test/posting_period_test.dart` | Tests weekday and ten-working-day calculations |
| Migration test | `test/app_database_migration_test.dart` | Tests the v4-to-v5 migration with an existing student and posting |
| GitHub CI/deployment | `.github/workflows/deploy-flutter-web.yml` | Generates Drift code, tests, builds web and deploys Pages from main |

**When debugging, start at the layer that owns the behaviour.** A form validation problem belongs first in the page/form. A capacity or allocation problem belongs in the repository. A missing column belongs in the table schema/migration and generated code. A file that is created but not downloaded belongs in the export service/browser interaction.

---

## 3. Database: the current data model

The database is defined in `lib/database/app_database.dart`. The current schema version is **5**.

### 3.1 Students

| Column | Current rule | Meaning |
|---|---|---|
| `id` | Auto-increment primary key | Internal student record ID |
| `name` | Required database value; empty string allowed; maximum 120 characters | Display name |
| `phoneNumber` | Required database value; empty string allowed; maximum 30 characters | Contact number |
| `groupName` | Non-empty; maximum 80 characters | Group identifier; the current form offers A or B |
| `createdAt` | Defaults to current date/time | Record creation time |

Name and phone are optional in the form. The repository trims whitespace, so a value containing only spaces is saved as an empty string (`''`), not SQL `NULL`. The columns remain non-nullable strings.

The current UI requires a group selection. The database itself checks that the group is non-empty, while the posting-preview code accepts only A or B (case-insensitive after trimming). A bad or legacy group value can therefore exist in the database but make preview generation fail.

### 3.2 Posting units

| Column | Current rule | Meaning |
|---|---|---|
| `id` | Auto-increment primary key | Internal unit ID |
| `name` | Non-empty, max 120, unique | Unit name |
| `sortOrder` | Defaults to 0 | Controls unit ordering during allocation |
| `isActive` | Defaults to true | Whether the unit can receive new assignments |

An inactive unit is retained. It is excluded from future previews, but its row and any existing student assignment remain available for display.

### 3.3 Postings

| Column | Current rule | Meaning |
|---|---|---|
| `id` | Auto-increment primary key | Posting-row ID |
| `studentId` | Foreign key to Students; unique | One current posting row per student |
| `unitId` | Foreign key to PostingUnits | Current assigned unit |
| `batchId` | Required integer | Identifies the most recent generation/confirmation batch |
| `scheduleOfDuty` | Nullable | Optional schedule text |
| `postedAt` | Defaults to current date/time | Time of the current assignment update |
| `periodStartDate` | Nullable date/time | Current posting period start |
| `periodEndDate` | Nullable date/time | Current posting period end |

### 3.4 A crucial history limitation

The current schema has a **unique constraint on `Postings.studentId`**. The application stores one current posting row per student. When a later generation is confirmed, the existing row is updated with the new unit, batch ID, posting time and period dates.

This means the current schema is **not a full posting-history or audit-log system**. It does not preserve a permanent row for every previous two-week cycle. A new confirmation replaces the student's current assignment details.

Do not promise a coordinator that the application can reconstruct every previous posting cycle unless a separate immutable history table is designed and implemented.

---

## 4. How the posting allocator actually works

### 4.1 First, a naming correction

The code does **not** implement the standard Boston school-allocation mechanism. The current implementation is a custom **group-aware, capacity-limited, rotating least-loaded allocator**, with an additional singleton-adjustment pass.

It does not collect student preferences, run preference rounds, or implement a classic Boston matching process. Calling it “the Boston algorithm” would misdescribe the code. In this guide, “posting allocator” means the implementation in `PostingRepository.buildPostingPreview()`.

### 4.2 Inputs and ordering

When a preview is built, the repository:

1. Loads students ordered by ascending student ID (the order in which records were inserted).
2. Loads active posting units ordered by ascending `sortOrder`.
3. Rejects the operation if there are no students.
4. Rejects the operation if there are no active posting units.
5. Separates students into Group A and Group B. The group value is trimmed and uppercased. Any value other than A or B causes an error.
6. Loads current posting rows so it can determine each existing student's previous unit.

The allocator processes Group A first and then Group B. Students inside each group are processed in student-ID order. Unit order matters. Changing `sortOrder` or changing which units are active can change later assignments.

### 4.3 Capacity rule

A unit can receive at most:

- **2 students from Group A**, and
- **2 students from Group B**

in the same generation.

The groups are counted independently. A unit can therefore have up to four students in total if two belong to A and two belong to B.

Required active-unit capacity is calculated separately for each group:

```text
required units for a group = ceiling(group student count / 2)
```

Examples:

| Group size | Minimum active units needed |
|---:|---:|
| 1 or 2 | 1 |
| 3 or 4 | 2 |
| 5 or 6 | 3 |
| 21 or 22 | 11 |
| 23 or 24 | 12 |

If either group needs more active units than are available, preview generation stops before any new posting is saved. The error reports the group and shortage. Add or activate enough units, then build a new preview.

### 4.4 How one student is assigned

For each student:

- A new student with no previous posting starts searching from the first active unit.
- An existing student whose previous unit is still active starts searching from the next active unit in the configured unit order (wraps back to the beginning).
- If the student's previous unit is no longer active, it is not found in the active-unit list; the student starts from the first active unit.
- Starting from that point, the allocator scans the active units in circular order.
- It selects a unit with fewer than two students from that group and with the lowest current count.
- When two candidate units have the same count, the first one encountered from that student's start position wins.
- If no unit has remaining capacity, an error is raised.

This is a greedy, order-dependent process. It does not search every possible assignment for a globally optimal result.

### 4.5 The singleton-adjustment pass

After the initial pass for a group, the code looks for units with exactly one student in that group.

- It takes the **first** singleton found in unit order.
- It looks for another unit that currently has two students in this group and is also used by the other group.
- If none qualifies, it falls back to the first other unit that has two students in this group.
- It moves the **last student assigned to that full unit** into the singleton unit.
- The group count is updated.

This is a limited adjustment, not a guarantee that every unit will be filled evenly. The code handles at most one singleton per group in this pass. In some cases it does nothing.

### 4.6 Worked examples for even and odd student counts

Assume units U1, U2 and U3 are active, ordered U1 then U2 then U3, and students are new (no previous postings).

**Six students in one group (even):**

Initial placement rotates through the least-loaded units:

| Student | Initial unit |
|---|---|
| 1 | U1 |
| 2 | U2 |
| 3 | U3 |
| 4 | U1 |
| 5 | U2 |
| 6 | U3 |

Counts are U1=2, U2=2, U3=2. There is no singleton to adjust.

**Five students in one group (odd):**

Initial counts are U1=2, U2=2, U3=1. U3 is the first singleton. The adjustment moves the last student from a full unit into U3. For the first group, where the other group has not yet been placed, the fallback selects the first full unit. The resulting counts are U1=1, U2=2, U3=2.

**Three students in two active units (odd):**

Initial counts are U1=2, U2=1. The singleton adjustment can move the last student from U1 to U2, resulting in U1=1, U2=2.

**Four students in three active units (even, but more units than needed):**

Initial counts are U1=2, U2=1, U3=1. The code adjusts only the first singleton. It can move one student from U1 to U2, leaving U1=1, U2=2, U3=1. This is an important edge case: an even number of students does not guarantee an even or fully packed distribution when many units are available.

### 4.7 What affects the next generation?

The previous assignment matters. The allocator does not simply restart every student at U1 on every generation:

- If a student's last assigned unit remains active, the next search starts from the following active unit.
- If that unit is deactivated, the student restarts from the first active unit.
- New students start from the first active unit.
- The least-loaded rule and tie-breaking still apply after the start position is selected.

A preview does not perform this advancement in the database. It only calculates a proposed next assignment. The advancement occurs only when the coordinator confirms the preview.

### 4.8 Algorithm limitations to remember

- The result depends on student registration order, active unit order and previous assignments.
- The singleton adjustment is intentionally limited and can leave multiple singleton units.
- The allocator does not calculate a global optimum.
- The code does not save the reasoning trace for why a student received a unit.
- It does not use public-holiday data or a calendar of staff availability.
- It does not implement a coordinator override/edit-assignment screen.
- A later confirmed generation updates current assignments; it does not create a permanent historical batch.

If the allocation rules change, update the algorithm tests as well as the code. Section 11 gives a safe procedure.

---

## 5. Posting dates, preview and confirmation

### 5.1 Date calculation

The dashboard's selected start date defaults to the next weekday. The date picker allows weekdays only. The current date utility calculates ten working days **including the start date as day one**:

- Saturday and Sunday are skipped.
- Public holidays are **not** skipped. A weekday public holiday counts as a working day in the current code.
- The end date is checked again during confirmation.
- The selected start and calculated end dates are saved on each current posting row when confirmation succeeds.

Example: Monday 2 November 2026 is day one; Friday 13 November 2026 is day ten.

The date utility is in `lib/utils/posting_period.dart`. If public holidays must be excluded in a future version, add a reliable holiday source/calendar and tests. Do not only change the wording on the screen.

### 5.2 Preview is read-only

When **Preview Posting** is clicked:

- The page calls `buildPostingPreview()`.
- It calculates assignments in memory.
- It shows the department heading, effective dates, group counts and proposed table.
- It does not write postings or advance students.

The preview is loaded when the preview page is created. It is not a live editable draft.

### 5.3 What confirmation does

When **Confirm Posting** is clicked, the repository checks:

1. The preview is not empty.
2. The start date is a weekday.
3. The current student count still matches the preview.
4. Each student in order still has the same ID, name, phone and group as the preview.
5. Each preview unit still exists, is active, and has the same name.
6. The provided end date matches the calculated tenth working day.

If those checks pass, the repository writes all assignments inside a database transaction. A transaction prevents a partial set of posting rows from being committed if a write in that transaction fails.

If student or unit data changed after preview, confirmation is rejected. Return to the dashboard and create a fresh preview. Do not try to force the old preview through.

**Concurrency note:** Some stale-preview reads occur before the write transaction begins. The application is designed for a single coordinator workflow, not simultaneous editing from multiple tabs or users. Multiple-tab concurrent changes are a known area that needs additional protection and testing before making this a shared multi-user system.

### 5.4 Confirmation and export are connected to the open preview page

The preview page keeps its `_confirmed` state and preview list in widget memory. Export buttons are shown only after confirmation on that page.

If the PDF or Excel download fails, stay on that preview page and retry the export. If the page is closed and a new preview is opened, the application builds a new proposal from current assignments. That new proposal may represent the next rotation, not the previous preview. The system does not yet persist a separate exportable, immutable preview-batch record.

---

## 6. What the operator can and cannot do

### 6.1 Student records

**Implemented:**
- Add a student.
- Name may be blank.
- Phone may be blank.
- Group must be selected in the form (A or B).
- Delete a student after confirmation.

**Not implemented:**
- Edit an existing student's name, phone or group.
- Archive a student without deleting their current posting.
- Restore a deleted student with the same identity/history.

Deleting a student deletes that student's current posting row and the student row in one transaction. This is destructive. There is no undo button. If the student must remain in the records, do not delete them just to correct a name or phone number.

If the wrong group was saved, the current UI has no edit function. Stop and plan a safe correction with a database backup and a tested migration/admin-edit feature rather than casually deleting the record.

**Data-quality warning:** The current implementation allows both name and phone to be empty at the same time. The record remains internally identifiable by its database ID, but a printed list could contain a row with no human-readable identity. Before operational use, consider requiring at least one identifier or adding an official student/matriculation number.

### 6.2 Posting units

**Implemented:**
- Add a unit.
- Rename a unit.
- Activate/deactivate a unit.
- Delete a unit only when no posting row refers to it.

A unit with posting records cannot be deleted. The repository rejects that deletion to protect the posting relationship. If a unit is temporarily unavailable, turn it off instead.

Deactivating a unit:
- Keeps the unit row.
- Keeps current assignment rows that refer to it.
- Excludes it from the next preview.
- Causes a student whose previous unit is now inactive to restart from the first active unit in the next allocation.

The last active unit cannot be switched off. At least one active unit must remain.

### 6.3 Posting records and history

There is no dedicated posting-history screen, no direct posting-row editor and no rollback-to-previous-cycle feature. A new confirmation updates the current posting for each student.

### 6.4 Excel and PDF

**Excel:**
- Generated from the preview list using an in-browser XLSX/ZIP builder.
- The workbook is an independent downloaded copy.
- Editing the workbook does not update SQLite or the PDF.
- The export contains the department heading, effective dates and the S/N, Name, Phone Number, Group and Posting columns.
- It is not a full database backup and cannot restore students or inactive units to the app.

**PDF:**
- Generated from the same preview list.
- Uses Noto Sans through `PdfGoogleFonts`.
- Font loading may require internet access. If the font request fails, PDF generation can fail and the page reports the error.
- The PDF is a separate downloaded document and does not sync with later Excel edits.

---

## 7. Failure guide: symptoms, causes and recovery

| Symptom | Likely cause | Safe response |
|---|---|---|
| Dashboard opens but student count is zero | Wrong browser origin/profile, a cleared browser database, or a genuinely empty database | Confirm the exact URL, scheme, host and port used before. Do not clear site data. Check whether you are using the same browser profile and device. |
| Preview says there are no students | Student table is empty | Open Record and add the records. |
| Preview says no active units | Every unit is inactive or no units exist | Open Posting Units and activate a valid unit or add one. Keep at least one active. |
| Preview reports insufficient active units | One group needs more active destinations than are available | Calculate `ceil(group size / 2)` for A and B independently. Add or activate enough units. |
| Preview reports an unsupported group | A stored group value is not A or B after trimming/case conversion | The current UI has no student edit screen. Do not delete a student with a posting just to fix the value; use a planned, backed-up correction. |
| Confirm Posting rejects the preview | Student details/count or unit name/availability changed after preview, or dates do not match | Go back, resolve the underlying records, then create a fresh preview and confirm that one. |
| Confirm button is not clickable | Confirmation is already in progress, or the page is in a state where no preview is available | Check for a spinner/error. Wait for the active operation to finish. If it remains stuck, inspect browser console and reproduce with a fresh page only after noting the current state. |
| Export buttons are not visible | Posting has not been confirmed on this preview-page instance, or there is no preview | Confirm the preview first. Exports are intentionally gated by the page's `_confirmed` state. |
| Export PDF is temporarily disabled | PDF export is already running (`_exportingPdf` is true) | Wait for the current export. Do not click repeatedly. |
| Excel click appears to do nothing | Browser download permission, blocked download, browser behaviour, or an exception in the web export code | Check the browser's download tray/history and site download permissions. Open DevTools Console for errors. Try the app in a normal browser window. |
| PDF reports a generation error | PDF font download failed, browser download was blocked, or PDF generation threw an exception | Check internet access first because Noto Sans is fetched from Google Fonts. Retry while staying on the same preview page. |
| Name/phone appears blank in table/export | The field was intentionally left empty | This is valid in schema v5. Consider adding an additional identifier if blank records are operationally ambiguous. |
| A unit cannot be deleted | At least one current posting row references the unit | Deactivate it instead. Do not manually remove the database foreign-key relationship. |
| A unit cannot be turned off | It is the last active unit | Activate another unit first. |
| A student disappears after deletion | Student deletion also deletes their current posting | There is no undo/restore screen. Re-adding creates a new student ID and does not restore the prior posting history. |
| A button looks enabled but has no effect | Browser console exception, missing callback, overlay/layout issue, or a state transition failure | Inspect the exact button's `onPressed`/callback, widget state and console error. Do not randomly change unrelated UI code. |
| Font Roboto failed to load in the browser console | Flutter could not fetch a web font | This may affect typography/fallback only. It does not by itself prove a database or application failure. Check whether the UI still renders. |
| Console mentions WASM feature fallback | The browser lacks an optional capability such as shared workers/shared array buffers | A fallback implementation may be used. Treat it as a failure only if there is a real exception or the app stops working. |
| Flutter build warns about `dart:html` and WASM | Excel/PDF services use `dart:html` | The normal web build can still succeed. This is a WebAssembly compatibility/deprecation issue to address separately. |
| Drift says a column/companion/getter is missing | Generated code is stale or the schema and generated file disagree | Check `app_database.dart`, run Drift code generation, then analyze and test. Do not manually patch generated code as the first fix. |

### 7.1 If the app appears to have lost data

Use this order:

1. Stop making changes in the browser.
2. Check whether the URL has changed (especially localhost port, hostname, scheme or deployed origin).
3. Check that the same browser profile is open.
4. Check whether the site was opened in private/incognito mode.
5. Do not clear browser data or reinstall the browser.
6. If the old origin/profile is available, reopen that exact app address and inspect the data there.

There is currently no supported in-app backup/restore command. If important production data is involved, avoid experiments and plan a proper export/backup path before upgrading or changing storage.

---

## 8. Database migrations: what they mean and how to change the schema safely

A **database migration** is a controlled set of operations that changes an existing user's database structure while preserving the data that should survive.

Changing a Dart table declaration does not automatically alter a database that already exists in someone's browser. The application's schema version and migration code tell Drift how to move an older database to the new structure.

### 8.1 Current migration timeline

| Version | Change |
|---:|---|
| v1 | Original database baseline |
| v2 | Existing migration step in the project |
| v3 | Adds `PostingUnits.isActive` |
| v4 | Adds `Postings.periodStartDate` and `periodEndDate` |
| v5 | Allows empty name/phone strings by rebuilding the Students table with zero as the minimum text length |

The current `onUpgrade` code applies all relevant steps in order when an older database opens. New databases are created directly using the latest table definitions.

The v4-to-v5 migration test creates a v4-style database containing an existing student and posting, opens it with the current database class, checks that the records still exist, inserts blank name/phone values, and checks foreign-key integrity.

### 8.2 When does an algorithm change need a migration?

**Changing only the allocation logic usually does not need a database migration.**

For example, changing the tie-breaking order or changing how odd groups are adjusted can be a code-only change if the database tables and stored data format remain the same. It still needs updated algorithm tests.

A migration is needed when you change stored structure or constraints, for example:
- Add, remove or rename a table column.
- Add a new table.
- Change nullability or a database constraint.
- Change how stored values are represented.
- Split one table into several or combine tables.

### 8.3 Safe schema-change procedure

1. Inspect the current schema and identify what existing records must be retained.
2. Make a backup plan before touching real user data. The current app has no in-app backup/restore feature; do not pretend an Excel export is a full database backup.
3. Change table declarations in `lib/database/app_database.dart`.
4. Increase `schemaVersion` by exactly one (current version is 5, so the next version is 6).
5. Add a new conditional migration block, such as `if (from < 6)`. Do not rewrite old migration steps that may already have run on users' databases.
6. Regenerate Drift code.
7. Add a migration test that starts with the previous schema and real-looking existing records, upgrades, then verifies the records and relationships.
8. Run all tests, analysis and a web build.
9. Review the migration diff carefully before merging.

Example shape only (not a complete migration):

```dart
@override
int get schemaVersion => 6;

// Inside onUpgrade:
if (from < 6) {
  // Add the carefully designed v5 -> v6 migration here.
}
```

### 8.4 Regenerate Drift code

After changing Drift table declarations:

```powershell
flutter pub get
dart run build_runner build
```

If the generator is stuck on stale cached state:

```powershell
dart run build_runner clean
dart run build_runner build
```

The GitHub Actions workflow currently invokes:

```sh
dart run build_runner build --delete-conflicting-outputs
```

One local run in the development environment reported that this option had been removed/ignored, although code generation still completed. If your local version prints that same warning, use the clean-then-build sequence above.

**Never start by manually editing `app_database.g.dart`.** It is generated from `app_database.dart`. A manual edit can be overwritten on the next build and can leave table classes, companions and validation metadata inconsistent.

### 8.5 Database-change verification checklist

- Does a new empty database create all current tables?
- Does an old supported database upgrade without losing rows?
- Are existing posting foreign keys still valid?
- Can new rows be inserted using the new constraints?
- Can old rows still be read and exported?
- Does `PRAGMA foreign_key_check` report no violations in the migration test?
- Do all repository tests pass?
- Does the web build succeed?

---

## 9. Manual code repair: a disciplined first response

The goal of a manual fix is to identify the failing layer and make the smallest justified change.

### 9.1 Read the failure before editing

1. Copy the first actual error and its file/line number.
2. Read the surrounding code.
3. Identify whether it is a form, repository, database, generated-code, export or Git problem.
4. Check whether the failing code path has a test.
5. Change one thing at a time.
6. Run the narrow test first, then the full suite.

Do not treat all analyzer `info` messages as compilation failures. In the current project, string-interpolation suggestions and `dart:html` deprecation notices were informational. A real compile error is different.

### 9.2 Standard project verification

```powershell
flutter pub get
flutter analyze
flutter test
flutter build web
```

The current GitHub workflow also runs Drift generation before tests and a release web build.

### 9.3 Fixing common Drift generated-code errors

Symptoms include:
- A companion constructor does not accept a new named parameter.
- A database row has no getter for a newly declared column.
- Tests cannot access a new generated field.
- Migration code has a type mismatch because generated table metadata is stale.

Procedure:

```powershell
flutter pub get
dart run build_runner clean
dart run build_runner build
flutter analyze
flutter test
```

Then inspect:
- The table declaration in `lib/database/app_database.dart`.
- The schema version and migration block.
- Whether `lib/database/app_database.g.dart` changed.
- Whether all errors refer to the same missing or outdated field.

Do not lower constraints or change migration logic just to silence a generated-code error. First prove which source declaration is wrong.

### 9.4 Fixing a student-save failure

Trace the path:

```text
Record form
  -> _addStudent()
  -> PostingRepository.addStudent()
  -> StudentsCompanion.insert(...)
  -> Students table constraint
```

Current expected behaviour:
- Name is trimmed; empty is stored as `''`.
- Phone is trimmed; empty is stored as `''`.
- Group is required by the form.
- Unsupported group data is rejected when building the posting preview.

If save fails, inspect the actual exception and verify the database schema is v5. Do not make the fields nullable unless the data model is deliberately being changed from empty strings to SQL NULL; those are different designs.

### 9.5 Fixing a preview/capacity failure

Trace:

```text
Preview Posting button
  -> PostingPreviewPage
  -> buildPostingPreview()
  -> load students and active units
  -> validate groups and capacity
  -> return preview items
```

Check in order:
1. Are there students?
2. Are there active units?
3. Are every student's groups A or B?
4. Does each group fit the active-unit capacity?
5. Are previous unit IDs still present among active units?
6. Did the user change a student or unit after the preview was opened?

Do not change the capacity formula unless the business rule itself has changed and the tests are updated.

### 9.6 Fixing an export failure

For Excel:
- Confirm the posting was confirmed on the open preview page.
- Check the browser download tray and permission.
- Inspect console errors around Blob/object URL/anchor click.
- Open the generated workbook in Excel or LibreOffice to validate its contents.

For PDF:
- Confirm the preview is still open and confirmed.
- Check network access to Google Fonts.
- Inspect the PDF error shown by the page and browser console.
- If offline PDF export is a requirement, bundle a supported font in the application rather than relying on a remote font request.

---

## 10. Git and GitHub: how to work without losing code

### 10.1 The basic Git vocabulary

| Term | Meaning |
|---|---|
| Working tree | Files currently on your computer |
| Staging area | The exact changes prepared for the next commit |
| Commit | A saved snapshot in local Git history |
| Branch | A separate line of work |
| Remote | The GitHub repository, commonly named `origin` |
| `origin/main` | Your local record of the latest main branch that you last fetched |
| Fetch | Downloads GitHub history/branch updates without merging them into your current branch |
| Pull | Fetches and then integrates the remote branch into your current branch |
| Push | Uploads your local commits to GitHub |
| Pull request (PR) | A proposed change from a branch that can be reviewed and merged |

**Commit is not push.** A local commit stays on your computer until it is pushed. Fetch does not overwrite your working files. Pull integrates remote work into the current local branch.

### 10.2 A safe feature workflow

Start by checking the repository:

```powershell
git status
git switch main
git fetch origin
git log --oneline --graph --decorate --left-right main...origin/main
```

If local main and origin/main have diverged, inspect the commits before merging. Do not blindly reset or overwrite either side.

When main is synchronized and the working tree is safe:

```powershell
git pull --no-rebase origin main
git switch -c feature/short-description
```

Make a focused change, then inspect it:

```powershell
git status
git diff
git diff --check
flutter analyze
flutter test
flutter build web
```

Stage and commit only the intended files:

```powershell
git add path/to/file.dart path/to/test_file.dart
git diff --cached
git commit -m "Describe the change"
```

To publish a feature branch for a PR (this is the step that uploads commits):

```powershell
git push -u origin feature/short-description
```

Open a PR to `main`, review the diff, inspect CI and review comments, fix valid findings, then merge the PR. Do not develop directly on `main` for ordinary features.

### 10.3 Understanding status and differences

Useful commands:

```powershell
git status
git diff
git diff --cached
git log --oneline --graph --decorate -10
git log --oneline --graph --decorate --left-right main...origin/main
git show --stat --oneline HEAD
git diff --name-only --diff-filter=U
```

- `git diff`: unstaged file changes.
- `git diff --cached`: staged changes that will be committed.
- `git diff --name-only --diff-filter=U`: paths still in an unresolved merge conflict.
- `git log ... main...origin/main`: shows which commits are only local and which are only on the fetched remote-tracking branch.

### 10.4 Merge conflicts: how to recognise and fix them

A merge conflict means Git cannot safely combine two edits to the same area. It does not automatically mean either version is wrong.

A conflicted file may contain markers:

```text
<<<<<<< HEAD
your current local version
=======
incoming version
>>>>>>> origin/main
```

Steps:

1. Run `git status` and identify every conflicted file.
2. Open one file at a time in VS Code.
3. Read both sides and understand what each change was trying to do.
4. Decide whether to keep one side or combine both. Do not choose “Accept Current” or “Accept Incoming” blindly.
5. Remove the conflict markers and leave valid code.
6. Save the file.
7. Run `git diff --check` and inspect the full file.
8. Stage the resolved file with `git add path/to/file`.
9. Repeat until `git diff --name-only --diff-filter=U` returns no paths.
10. Run tests before completing the merge.

Git's “ours” means the current checked-out branch; “theirs” means the branch being merged in. They do not mean “best” and “worst”.

For a file that you have deliberately decided should exactly match the fetched GitHub main version during a merge, this command restores that specific file from the incoming branch:

```powershell
git restore --source=origin/main --worktree -- path/to/file.dart
git add path/to/file.dart
```

Use this only when you have inspected the file and explicitly want the incoming version. It discards the current working-tree content for that path.

If you need to abandon an unfinished merge before committing it:

```powershell
git merge --abort
```

This attempts to return to the pre-merge state. Check `git status` first. Do not use it after the merge has already been committed.

### 10.5 If Git opens Vim for a commit message

Git may open Vim when it needs a merge commit message.

- Press `Esc` (or `Ctrl+[`) to leave INSERT mode.
- Type `:wq` and press Enter to save and exit.
- If you accidentally typed text into the message and want to exit without saving the message, leave INSERT mode, type `:q!`, and press Enter. Then, if Git still reports a merge in progress and the default merge message is acceptable, run `git commit --no-edit`.

Do not close the terminal while a merge operation is in progress without checking Git's status.

### 10.6 Dangerous commands: stop and inspect first

Do not casually run these:

```powershell
git reset --hard
git clean -fd
git push --force
git checkout .
```

They can discard local work, untracked files, or remote history. Before any destructive command, identify exactly what would be lost and make a backup or branch if appropriate.

---

## 11. GitHub Actions: how to use it to diagnose a build

The repository workflow is `.github/workflows/deploy-flutter-web.yml`.

### 11.1 What the current workflow does

For the build job, it:
1. Checks out the repository.
2. Sets up stable Flutter.
3. Runs `flutter pub get`.
4. Runs Drift code generation.
5. Runs `flutter test`.
6. Runs a release web build with the GitHub Pages base path.
7. Uploads the web build artifact.

The deploy job is conditional: it runs for a push to `main` (not for a pull-request event) and depends on the build job succeeding.

**Current workflow gap:** The workflow does not run `flutter analyze`. Run it locally or add it as a separate CI step if every PR should be checked for analyzer errors. CodeRabbit review is also separate from this workflow; it is not the same thing as a passing GitHub Actions build.

### 11.2 Where to find the logs

1. Open the repository on GitHub.
2. Select the **Actions** tab.
3. Open **Build and deploy Flutter Web**.
4. Select the run that matches the PR number or commit.
5. Open the `build` job.
6. Expand the failed step (for example, Generate Drift database code, Run tests or Build Flutter web app).
7. Read the first meaningful error, not only the final “Process completed with exit code 1”.

If the PR build passes but the live site is not updated, inspect the push-to-main run and the deploy job as well. A PR build creates a validation artifact; it does not deploy the PR preview to the live Pages site.

### 11.3 What each failed step means

| Failed step | First place to investigate |
|---|---|
| Install dependencies | SDK constraint, pubspec.yaml, package resolution or network |
| Generate Drift database code | Table annotations/imports, schema declarations, generator errors |
| Run tests | First failing test and the code path it exercises |
| Build Flutter web app | Compile errors, unsupported web APIs, assets, imports |
| Upload artifact | Build output directory and Pages artifact permissions/configuration |
| Deploy | Pages environment, deployment permissions and the deployment job logs |

---

## 12. Risks and recommended improvements

These are not all defects that are currently occurring. They are risks or missing capabilities visible from the current architecture and code.

### High priority before long-term operational use

1. **Database backup and restore.** There is no in-app backup/restore function. A manual download of the posting sheet is not a database backup. Add a tested database backup/export and restore process.
2. **Central storage and multi-user support.** The browser database is local to a browser origin/profile. If several coordinators need one shared live dataset, move to a server database/API with authentication, permissions and conflict handling.
3. **Posting history and audit log.** Add immutable posting batches/history before users rely on being able to prove who was assigned where in an earlier cycle.
4. **Student editing.** The current UI adds and deletes students, but does not edit an existing student's group/name/phone. Add a safe edit operation with preview invalidation.
5. **Persistent confirmed batch.** Store a confirmed batch and its exact student-unit snapshot so exports can be retried later without creating the next rotation.
6. **Holiday-aware dates.** The code skips weekends only. Add an explicit holiday calendar/source and tests if public holidays should be excluded.

### Algorithm and data-quality improvements

7. Add exhaustive tests for odd/even group sizes, one student, many units, few units, inactive previous units, unit-order changes, and both groups interacting in the singleton adjustment.
8. Consider revising the singleton pass. It adjusts only the first singleton and can produce surprising results when there are more units than students. Write the desired business rule first, then test it before changing the implementation.
9. Add an official student identifier if name and phone may both be blank. Otherwise coordinators may have difficulty distinguishing identical-looking blank rows.
10. Move the stale-preview checks inside the same transaction as confirmation, or otherwise serialize writes, before supporting multiple simultaneous tabs/coordinators.
11. Add browser-level tests for download behaviour, form validation, disabled buttons and small-screen layouts. Repository unit tests do not exercise real browser download permissions.
12. Add `flutter analyze` to GitHub Actions so analyzer errors are caught in PR checks.

### Reliability and support improvements

13. Bundle the PDF font locally if offline export is required.
14. Replace deprecated `dart:html` usage with supported web interop APIs when practical, then test Excel and PDF downloads in target browsers.
15. Add meaningful logging/error reporting. Some UI handlers display a generic message such as “Could not add this student”, which hides the underlying exception from the operator.
16. Test realistic data volumes and longer usage, not only a small in-memory test database.
17. Add an explicit data-retention/deletion policy and secure the device/browser profile because student phone numbers are personal information.

---

## 13. Recommended test matrix before changing the allocator

At minimum, keep tests for these cases:

| Scenario | Expected result |
|---|---|
| No students | Preview fails with a clear message; no posting changes |
| Students exist, no active units | Preview fails; no posting changes |
| All students in A | Only A capacity is consumed |
| All students in B | Only B capacity is consumed |
| Both groups present | Each group independently respects the two-per-unit limit |
| Exactly 2 students in a group | One unit is enough |
| 3 students, 2 active units | Preview respects capacity and singleton adjustment |
| 4 students, 3 active units | Assert the actual chosen behaviour; do not assume perfect packing |
| 5 students, 3 active units | Minimum capacity is met and singleton adjustment is tested |
| 6 students, 3 active units | Two per unit in a new-student example |
| Capacity exceeded by one student | Preview fails before writing any assignment |
| Previous unit remains active | Next search begins after that unit |
| Previous unit is inactive | Student starts from the first active unit |
| Unit is renamed/deactivated after preview | Confirmation rejects stale preview |
| Student is added/deleted/changed after preview | Confirmation rejects stale preview |
| Confirmation write fails | Transaction does not leave a partial generation |
| Migration from v4 to v5 | Existing student/posting data survives; blank details can be inserted |
| PDF font unavailable | User receives a clear export error; saved posting remains unchanged |
| Browser blocks downloads | Data remains saved; operator can retry while preview state remains available |

The current repository tests cover several core cases, including capacity, group handling, read-only preview, stale student data, empty student details and the v4-to-v5 migration. This matrix also identifies important cases that should be added as the application matures.

---

## 14. A practical incident checklist

When a real user reports “the system is not working”:

- [ ] Record the exact screen, button and time of the failure.
- [ ] Ask what they clicked immediately before the failure.
- [ ] Capture the exact on-screen message.
- [ ] Check whether data is still visible before refreshing or changing browser settings.
- [ ] Confirm the full URL and browser profile.
- [ ] Inspect the browser DevTools Console for the first relevant error.
- [ ] Inspect the Network tab if a font or other network resource failed.
- [ ] Reproduce with test data before changing real records.
- [ ] Check Git status and current commit before editing source code.
- [ ] Make one minimal fix on a feature branch.
- [ ] Add or update a test for the failure.
- [ ] Run Drift generation when schema declarations changed.
- [ ] Run tests, analyzer and a web build.
- [ ] Review the PR and GitHub Actions before merging.
- [ ] Verify deployment separately after a main-branch merge.
- [ ] Record the root cause and the permanent fix in the project documentation.

## 15. Final operating principle

The safest response to a failure is not to guess and start changing code. Identify the layer, preserve the data, reproduce the failure, inspect the exact error, make the smallest fix, and add a test that would have caught it.

For this project in particular:

- Do not delete browser data to fix an empty screen.
- Do not edit generated Drift code by hand.
- Do not change schema constraints without a versioned migration.
- Do not describe the current allocator as the standard Boston algorithm.
- Do not promise historical posting recovery while only the current posting row is stored.
- Do not assume a successful unit test proves browser downloads, multi-user behaviour or long-term storage reliability.

This guide should be updated whenever the database schema, allocation rules, export services, storage architecture or GitHub workflow changes.
