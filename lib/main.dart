
import 'package:flutter/material.dart';
import 'package:akth_posting_web/pages/dashboard_page.dart';
import 'package:akth_posting_web/pages/record_page.dart';
void main() {
  runApp(const AKTHApp());
}

class AKTHApp extends StatelessWidget {
  const AKTHApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: ' SIWES Posting System',
      // home: Dashboard(),
      home: Record(),
    );
  }
}




