import 'package:flutter/material.dart';

import '../data/posting_repository.dart';
import '../database/app_database.dart';

class Record extends StatefulWidget {
  const Record({super.key, required this.repository});

  final PostingRepository repository;

  @override
  State<Record> createState() => _RecordState();
}

class _RecordState extends State<Record> {
  static const Color _pageColor = Color(0xFFF8F8F8);
  static const Color _mutedColor = Color(0xFF8F8D8D);
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _groupController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _groupController.dispose();
    super.dispose();
  }

  Future<void> _addStudent() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.repository.addStudent(
        name: _nameController.text,
        phoneNumber: _phoneController.text,
        groupName: _groupController.text,
      );
      _formKey.currentState!.reset();
      _nameController.clear();
      _phoneController.clear();
      _groupController.clear();
      _message('Student added.');
    } catch (_) {
      _message('Could not add this student.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _field(
    String label,
    TextEditingController controller,
    double width, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Required' : null,
          ),
        ],
      ),
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add New Student',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 700 ? 2 : 1;
                final width = columns == 2
                    ? (constraints.maxWidth - 20) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 20,
                  runSpacing: 14,
                  children: [
                    _field('Name', _nameController, width),
                    _field(
                      'Phone Number',
                      _phoneController,
                      width,
                      keyboardType: TextInputType.phone,
                    ),
                    _field('Group', _groupController, width),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 44,
              child: FilledButton.icon(
                onPressed: _saving ? null : _addStudent,
                icon: const Icon(Icons.add),
                label: Text(_saving ? 'Saving…' : 'Add Student'),
                style: FilledButton.styleFrom(backgroundColor: Colors.green),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _studentTable() {
    return StreamBuilder<List<Student>>(
      stream: widget.repository.watchStudents(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Text('Unable to load student records.');
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final students = snapshot.data!;
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
              Text('Total Students: ${students.length}'),
              const SizedBox(height: 12),
              if (students.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.note_alt_outlined,
                          size: 40,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No Records Yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('S/N')),
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Phone Number')),
                      DataColumn(label: Text('Group')),
                    ],
                    rows: [
                      for (var i = 0; i < students.length; i++)
                        DataRow(
                          cells: [
                            DataCell(Text('${i + 1}')),
                            DataCell(Text(students[i].name)),
                            DataCell(Text(students[i].phoneNumber)),
                            DataCell(Text(students[i].groupName)),
                          ],
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageColor,
      appBar: AppBar(
        title: const Text('Student Registry'),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add and Manage SIWES Students',
              style: TextStyle(color: _mutedColor),
            ),
            const SizedBox(height: 24),
            _studentForm(),
            const SizedBox(height: 24),
            _studentTable(),
          ],
        ),
      ),
    );
  }
}
