# AKTH SIWES Posting System

A Flutter web application for managing SIWES student records, posting units, and student postings. Student, unit, and posting data is stored in a local SQLite database through Drift.

## Current screens

- **Dashboard:** displays live student and unit totals. Generate Posting assigns students and downloads an Excel workbook of the full posting list.
- **Student Registry:** stores a student's name, phone number, and group in SQLite; removing a student also removes their current posting.
- **Posting Units:** starts with four editable units and supports adding, renaming, and deleting units without posting history.

## Posting behavior

Every click on Generate Posting advances each student's current assignment to the next unit in the configured unit order. Newly registered students are placed in the least-populated destination, with unit order breaking ties. This is a manual, click-based update; there is no two-week timer. After updating assignments, the app downloads `AKTH_SIWES_Postings.xlsx` with the full current posting list.

See [POSTING_ALGORITHM_README.md](POSTING_ALGORITHM_README.md) for the algorithm rules and a worked example.

The web database uses the SQLite WASM runtime and Drift worker in `web/`.

## Responsive layout

The Student Registry adapts to different browser widths:

- On wide screens, navigation stays in a left sidebar; on narrower screens, it moves into a menu drawer.
- Dashboard summary cards sit side by side when there is room and stack on smaller screens.
- Student form fields use two columns when there is room and stack vertically on smaller screens.
- Both pages scroll vertically, and the registry table can scroll horizontally when its columns do not fit.
- Fixed content widths and large fixed spacer gaps were removed to avoid common small-screen overflow.

## Current limitations

Logout is not implemented.

## Run locally

Install Flutter, then run:

```sh
flutter pub get
flutter run -d chrome
```

The project requires a Dart SDK matching the constraint in `pubspec.yaml`.
