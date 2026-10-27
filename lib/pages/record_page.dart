import 'package:flutter/material.dart';

class Record extends StatefulWidget {
  const Record({super.key});

  @override
  State<Record> createState() => _RecordState();
}

class _RecordState extends State<Record> {
  static const Color _pageColor = Color.fromRGBO(248, 248, 248, 1);
  static const Color _mutedColor = Color.fromARGB(255, 143, 141, 141);

  Widget _navigation({bool inDrawer = false}) {
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
                    'Siwes Posting System',
                    style: TextStyle(fontSize: 12, color: _mutedColor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            _navItem(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              onTap: () => Navigator.pop(context),
            ),
            _navItem(icon: Icons.people_outline, label: 'Record', selected: true),
            const Spacer(),
            _navItem(icon: Icons.logout, label: 'Logout', color: Colors.red),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
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

  Widget _studentForm() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add New Student', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 700 ? 2 : 1;
              final fieldWidth = columns == 2
                  ? (constraints.maxWidth - 20) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 20,
                runSpacing: 14,
                children: [
                  _field('Name', fieldWidth),
                  _field('Phone Number', fieldWidth),
                  _field('Group', fieldWidth),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 44,
            child: FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Add Student'),
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, double width) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const SizedBox(
            height: 42,
            child: TextField(
              decoration: InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _studentTable() {
    const headers = ['S/N', 'Name', 'Phone Number', 'Group', 'Posting', 'Schedule of Duty'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total Students: 0'),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 820,
              child: Column(
                children: [
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black26),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: List.generate(headers.length, (index) => Expanded(
                        flex: index == headers.length - 1 ? 2 : 1,
                        child: Text(headers[index], style: const TextStyle(fontWeight: FontWeight.bold)),
                      )),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Icon(Icons.note_alt_outlined, size: 40, color: Colors.grey),
                  const SizedBox(height: 8),
                  const Text('No Records Yet', style: TextStyle(color: Colors.grey)),
                ],
              ),
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
          drawer: isWide ? null : Drawer(child: _navigation(inDrawer: true)),
          body: Row(
            children: [
              if (isWide) _navigation(),
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
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(isWide ? 30 : 20, isWide ? 30 : 8, isWide ? 30 : 20, 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Student Registry', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 5),
                              const Text('Add and Manage SIWES Students', style: TextStyle(color: _mutedColor)),
                              const SizedBox(height: 24),
                              _studentForm(),
                              const SizedBox(height: 24),
                              _studentTable(),
                            ],
                          ),
                        ),
                      ),
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
