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
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Unit name'), textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    try {
      await widget.repository.saveUnit(id: unit?.id, name: name);
    } catch (error) {
      if (mounted) _message(error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> _setAvailability(PostingUnit unit, bool isActive) async {
    try {
      await widget.repository.setUnitActive(unit.id, isActive: isActive);
    } catch (error) {
      if (mounted) _message(error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> _deleteUnit(PostingUnit unit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete posting unit?'),
        content: Text('Delete ' + unit.name + '? Units with posting history cannot be deleted. If this unit is temporarily unavailable, switch it off instead.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.deleteUnit(unit.id);
    } catch (error) {
      if (mounted) _message(error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  void _message(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(title: const Text('Posting Units'), backgroundColor: Colors.white),
      floatingActionButton: FloatingActionButton.extended(onPressed: _editUnit, icon: const Icon(Icons.add), label: const Text('Add Unit'), backgroundColor: Colors.green, foregroundColor: Colors.white),
      body: StreamBuilder<List<PostingUnit>>(
        stream: widget.repository.watchUnits(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Unable to load posting units.'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final units = snapshot.data!;
          if (units.isEmpty) return const Center(child: Text('No posting units yet. Add your first unit.'));
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
            itemCount: units.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final unit = units[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: unit.isActive ? Colors.green.shade50 : Colors.grey.shade200, child: Icon(Icons.business_outlined, color: unit.isActive ? Colors.green : Colors.grey)),
                  title: Text(unit.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(unit.isActive ? 'Accepting students' : 'Not available for new postings'),
                  trailing: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Switch(value: unit.isActive, onChanged: (value) => _setAvailability(unit, value)),
                      IconButton(tooltip: 'Edit unit', onPressed: () => _editUnit(unit: unit), icon: const Icon(Icons.edit_outlined)),
                      IconButton(tooltip: 'Delete unit', onPressed: () => _deleteUnit(unit), icon: const Icon(Icons.delete_outline, color: Colors.red)),
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