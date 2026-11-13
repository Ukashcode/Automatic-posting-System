import 'package:flutter/material.dart';
import 'package:akth_posting_web/pages/record_page.dart';
import 'package:akth_posting_web/pages/units_page.dart';
import 'package:akth_posting_web/data/posting_repository.dart';
import 'package:akth_posting_web/database/app_database.dart';
import 'package:akth_posting_web/pages/posting_preview_page.dart';
import 'package:akth_posting_web/utils/posting_period.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key, required this.repository});

  final PostingRepository repository;

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  PostingRepository get repository => widget.repository;
  DateTime _selectedStartDate = PostingPeriod.nextWeekday(DateTime.now());

  static const Color _pageColor = Color.fromRGBO(248, 248, 248, 1);
  static const Color _mutedColor = Color.fromARGB(255, 143, 141, 141);

  void _openRecords(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Record(repository: repository)),
    );
  }

  void _openUnits(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UnitsPage(repository: repository)),
    );
  }

  Future<void> _chooseStartDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedStartDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      selectableDayPredicate: PostingPeriod.isWeekday,
      helpText: 'Select posting start date',
    );
    if (selected != null && mounted) {
      setState(() => _selectedStartDate = selected);
    }
  }

  void _openPostingPreview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostingPreviewPage(
          repository: repository,
          periodStartDate: _selectedStartDate,
        ),
      ),
    );
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
              padding: EdgeInsets.fromLTRB(12, 18, 12, 0),
              child: Column(
                children: [
                  Image(
                    image: AssetImage(
                      'images/cropped-akth_logo-removebg-preview-2-1.png',
                    ),
                    width: 84,
                    height: 84,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'SIWES Posting System',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: _mutedColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            _navItem(Icons.dashboard_outlined, 'Dashboard', selected: true),
            _navItem(
              Icons.people_outline,
              'Record',
              onTap: () => _openRecords(context),
            ),
            _navItem(
              Icons.business_outlined,
              'Posting Units',
              onTap: () => _openUnits(context),
            ),
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
      title: Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
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
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 14, color: _mutedColor)),
        ],
      ),
    );
  }

  Widget _dashboardContent(BuildContext context, bool isWide) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isWide ? 30 : 20,
        isWide ? 30 : 8,
        isWide ? 30 : 20,
        28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'AKTH SIWES AUTOMATIC POSTING SYSTEM',
            style: TextStyle(
              fontSize: 12,
              color: _mutedColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          StreamBuilder<List<Student>>(
            stream: repository.watchStudents(),
            builder: (context, studentsSnapshot) =>
                StreamBuilder<List<PostingUnit>>(
                  stream: repository.watchActiveUnits(),
                  builder: (context, unitsSnapshot) => LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 620 ? 2 : 1;
                      final cardWidth = columns == 2
                          ? (constraints.maxWidth - 16) / 2
                          : constraints.maxWidth;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          SizedBox(
                            width: cardWidth,
                            child: _summaryCard(
                              icon: Icons.people_outline,
                              value: '${studentsSnapshot.data?.length ?? 0}',
                              label: 'Number of Students',
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _summaryCard(
                              icon: Icons.other_houses_rounded,
                              value: '${unitsSnapshot.data?.length ?? 0}',
                              label: 'Available Units',
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Posting period', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      PostingPeriod.formatDate(_selectedStartDate) + '  -  ' +
                          PostingPeriod.formatDate(PostingPeriod.calculateEndDate(_selectedStartDate)),
                      style: const TextStyle(color: _mutedColor),
                    ),
                    const SizedBox(height: 4),
                    const Text('10 working days • Weekends excluded; public holidays still count', style: TextStyle(fontSize: 12, color: _mutedColor)),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: _chooseStartDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('Change start date'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _openPostingPreview,
            icon: const Icon(Icons.preview_outlined),
            label: const Text('Preview Posting'),
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
          drawer: isWide
              ? null
              : Drawer(child: _navigation(context, inDrawer: true)),
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
