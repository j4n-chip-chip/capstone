# capstone
The repository for my capstone

BananaDoctor is a Flutter/Firebase application for farm monitoring and sprayer
control. The uploaded source fixes and remaining backend/firmware requirements
are described in [docs/fix-notes.md](docs/fix-notes.md).

Run the standalone edge-case regressions with `dart test/edge_cases.dart`.
Check simultaneous listeners and subscription lifecycle with
`dart test/stream_edge_cases.dart`.
Widget regressions are in `test/widget_edge_cases_test.dart`; they require the
original Flutter project manifest and lockfile, which are not uploaded yet.
