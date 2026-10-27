# AKTH SIWES Posting System

A Flutter web interface prototype for managing SIWES student records and postings.

## Current screens

- **Dashboard:** displays student and available-unit summary cards and a posting action.
- **Student Registry:** provides fields for a student's name, phone number, and group, plus a records table.

## Responsive Student Registry

The Student Registry adapts to different browser widths:

- On wide screens, navigation stays in a left sidebar.
- On narrower screens, navigation moves into a menu drawer.
- The form fields use two columns when there is room and stack vertically on smaller screens.
- The page content scrolls vertically, while the records table can scroll horizontally when its columns do not fit.
- Fixed content widths and large fixed spacer gaps were removed to avoid common small-screen overflow.

## Current limitations

This is still a UI prototype. Student submission and posting generation are not connected to data storage or a backend, and the displayed dashboard totals are placeholders. Logout is also not implemented.

## Run locally

Install Flutter, then run:

```sh
flutter pub get
flutter run -d chrome
```

The project requires a Dart SDK matching the constraint in `pubspec.yaml`.
