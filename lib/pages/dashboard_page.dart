import 'package:flutter/material.dart';
import 'package:akth_posting_web/pages/record_page.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  static const Color _pageColor = Color.fromRGBO(248, 248, 248, 1);
  static const Color _mutedColor = Color.fromARGB(255, 143, 141, 141);

  void _openRecords(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const Record()));
  }

  Widget _navigation(BuildContext context, {bool inDrawer = false}) {
    return Container(
      width: inDrawer ? null : 200,
      color: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AKTH', style: TextStyle(fontSize: 20, color: Colors.green)),
                  Text(
                    'SIWES Posting System',
                    style: TextStyle(fontSize: 12, color: _mutedColor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            _navItem(Icons.dashboard_outlined, 'Dashboard', selected: true),
            _navItem(Icons.people_outline, 'Record', onTap: () => _openRecords(context)),
            const Spacer(),
            _navItem(Icons.logout, 'Logout', color: Colors.red),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _navItem(
    IconData icon,
    String label, {
    VoidCallback? onTap,
    bool selected = false,
    Color color = Colors.green,
  }) {
    return ListTile(
      leading: Icon(icon, color: color, size: 26),
      title: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      selected: selected,
      selectedTileColor: const Color(0xFFEAF5EC),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      dense: true,
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 150),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 36, color: Colors.green),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 14, color: _mutedColor)),
        ],
      ),
    );
  }

  Widget _dashboardContent(BuildContext context, bool isWide) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(isWide ? 30 : 20, isWide ? 30 : 8, isWide ? 30 : 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dashboard', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'AKTH SIWES AUTOMATIC POSTING SYSTEM',
            style: TextStyle(fontSize: 12, color: _mutedColor, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 620 ? 2 : 1;
              final cardWidth = columns == 2 ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _summaryCard(
                      icon: Icons.people_outline,
                      value: '0',
                      label: 'Number of Students',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _summaryCard(
                      icon: Icons.other_houses_rounded,
                      value: '4',
                      label: 'Available Units',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Generate Posting'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        return Scaffold(
          backgroundColor: _pageColor,
          drawer: isWide ? null : Drawer(child: _navigation(context, inDrawer: true)),
          body: Row(
            children: [
              if (isWide) _navigation(context),
              Expanded(
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isWide)
                        Builder(
                          builder: (context) => IconButton(
                            tooltip: 'Open navigation',
                            icon: const Icon(Icons.menu),
                            onPressed: () => Scaffold.of(context).openDrawer(),
                          ),
                        ),
                      Expanded(child: _dashboardContent(context, isWide)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
