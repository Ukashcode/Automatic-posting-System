import 'package:flutter/material.dart';
import 'package:akth_posting_web/pages/dashboard_page.dart';
import 'package:akth_posting_web/data/app_dependencies.dart';
import 'package:akth_posting_web/data/posting_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await postingRepository.ensureDefaultUnits();
  runApp(AKTHApp(repository: postingRepository));
}

class AKTHApp extends StatelessWidget {
  const AKTHApp({super.key, required this.repository});

  final PostingRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: ' SIWES Posting System',
      home: Dashboard(repository: repository),
      // home: Record(),
    );
  }
}
