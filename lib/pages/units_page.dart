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
    // The dialog owns its controller so it stays alive until the TextField
    // has actually been removed from the widget tree.
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _UnitEditorDialog(initialName: unit?.name ?? ''),
    );

    if (!mounted || name == null || name.trim().isEmpty) return;

    try {
      await widget.repository.saveUnit(id: unit?.id, name: name);
    } catch (error) {
      if (mounted) {
        _message(error.toString().replaceFirst('Bad state: ', ''));
      }
    }
  }

  Future<void> _setAvailability(PostingUnit unit, bool isActive) async {
    try {
      await widget.repository.setUnitActive(unit.id, isActive: isActive);
    } catch (error) {
      if (mounted) {
        _message(error.toString().replaceFirst('Bad state: ', ''));
      }
    }
  }

  Future<void> _deleteUnit(PostingUnit unit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete posting unit?'),
        content: Text(
          'Delete ' +
              unit.name +
              '? Units with posting history cannot be deleted. If this unit is temporarily unavailable, switch it off instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await widget.repository.deleteUnit(unit.id);
    } catch (error) {
      if (mounted) {
        _message(error.toString().replaceFirst('Bad state: ', ''));
      }
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value)),
    );
  }

  Widget _unitCard(PostingUnit unit) {
    final leading = CircleAvatar(
      backgroundColor:
          unit.isActive ? Colors.green.shade50 : Colors.grey.shade200,
      child: Icon(
        Icons.business_outlined,
        color: unit.isActive ? Colors.green : Colors.grey,
      ),
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          unit.name,
          softWrap: true,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          unit.isActive
              ? 'Accepting students'
              : 'Not available for new postings',
          softWrap: true,
        ),
      ],
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch(
          value: unit.isActive,
          onChanged: (value) => _setAvailability(unit, value),
        ),
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
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 560;

        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: isCompact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          leading,
                          const SizedBox(width: 12),
                          Expanded(child: details),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: actions,
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      leading,
                      const SizedBox(width: 12),
                      Expanded(child: details),
                      actions,
                    ],
                  ),
          ),
        );
      },
    );
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
          if (snapshot.hasError) {
            return const Center(
              child: Text('Unable to load posting units.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final units = snapshot.data!;
          if (units.isEmpty) {
            return const Center(
              child: Text('No posting units yet. Add your first unit.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
            itemCount: units.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _unitCard(units[index]),
          );
        },
      ),
    );
  }
}

class _UnitEditorDialog extends StatefulWidget {
  const _UnitEditorDialog({required this.initialName});

  final String initialName;

  @override
  State<_UnitEditorDialog> createState() => _UnitEditorDialogState();
}

class _UnitEditorDialogState extends State<_UnitEditorDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialName.isEmpty ? 'Add posting unit' : 'Edit posting unit',
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Unit name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
