import 'package:flutter/material.dart';

import '../data/posting_repository.dart';
import '../database/app_database.dart';

class UnitsPage extends StatefulWidget {
  const UnitsPage({super.key, required this.repository});

  final PostingRepository repository;

  @override
  State<UnitsPage> createState() => _UnitsPageState();
}

class _UnitsPageState extends State<UnitsPage> {
  Future<void> _editUnit({PostingUnit? unit}) async {
    final controller = TextEditingController(text: unit?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(unit == null ? 'Add posting unit' : 'Edit posting unit'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Unit name'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    try {
      await widget.repository.saveUnit(id: unit?.id, name: name);
    } catch (error) {
      if (mounted)
        _message('Could not save unit. Check that its name is unique.');
    }
  }

  Future<void> _deleteUnit(PostingUnit unit) async {
    try {
      await widget.repository.deleteUnit(unit.id);
    } on StateError catch (error) {
      _message(error.message);
    }
  }

  void _message(String? value) {
    if (value != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('Posting Units'),
        backgroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _editUnit,
        icon: const Icon(Icons.add),
        label: const Text('Add Unit'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<PostingUnit>>(
        stream: widget.repository.watchUnits(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const Center(child: Text('Unable to load posting units.'));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final units = snapshot.data!;
          if (units.isEmpty)
            return const Center(
              child: Text('No posting units yet. Add your first unit.'),
            );
          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: units.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final unit = units[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.shade50,
                    child: const Icon(
                      Icons.business_outlined,
                      color: Colors.green,
                    ),
                  ),
                  title: Text(
                    unit.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        tooltip: 'Edit unit',
                        onPressed: () => _editUnit(unit: unit),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Delete unit',
                        onPressed: () => _deleteUnit(unit),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
