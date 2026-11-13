import 'package:flutter/material.dart';

import '../data/posting_repository.dart';
import '../services/posting_excel_export_service.dart';
import '../services/posting_pdf_export_service.dart';
import '../utils/posting_period.dart';

class PostingPreviewPage extends StatefulWidget {
  const PostingPreviewPage({
    super.key,
    required this.repository,
    required this.periodStartDate,
  });

  final PostingRepository repository;
  final DateTime periodStartDate;

  @override
  State<PostingPreviewPage> createState() => _PostingPreviewPageState();
}

class _PostingPreviewPageState extends State<PostingPreviewPage> {
  final _excelExport = PostingExcelExportService();
  final _pdfExport = PostingPdfExportService();
  List<PostingPreviewItem> _preview = [];
  bool _loading = true;
  bool _confirming = false;
  bool _confirmed = false;
  bool _exportingPdf = false;
  String? _error;

  DateTime get _periodEndDate =>
      PostingPeriod.calculateEndDate(widget.periodStartDate);

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    try {
      final result = await widget.repository.buildPostingPreview();
      if (!mounted) return;
      setState(() {
        _preview = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Bad state: ', '');
        _loading = false;
      });
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _confirmPosting() async {
    setState(() => _confirming = true);
    try {
      await widget.repository.confirmPostingPreview(
        preview: _preview,
        periodStartDate: widget.periodStartDate,
        periodEndDate: _periodEndDate,
      );
      if (!mounted) return;
      setState(() {
        _confirmed = true;
        _confirming = false;
      });
      _message('Posting confirmed. You can now export the Excel or PDF copy.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _confirming = false);
      _message(error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  void _exportExcel() {
    _excelExport.download(
      _preview,
      periodStartDate: widget.periodStartDate,
      periodEndDate: _periodEndDate,
    );
    _message('Excel file generated. Changes made to that file will not change the saved posting or PDF.');
  }

  Future<void> _exportPdf() async {
    setState(() => _exportingPdf = true);
    try {
      await _pdfExport.download(
        _preview,
        periodStartDate: widget.periodStartDate,
        periodEndDate: _periodEndDate,
      );
      if (mounted) _message('Print-ready PDF generated.');
    } catch (error) {
      if (mounted) _message('Could not generate the PDF. ' + error.toString());
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupACount = _preview.where((item) => item.student.groupName.toUpperCase() == 'A').length;
    final groupBCount = _preview.where((item) => item.student.groupName.toUpperCase() == 'B').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('Posting Preview'),
        backgroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 42, color: Colors.orange),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Back to dashboard')),
                      ],
                    ),
                  ),
                )
              : _preview.isEmpty
                  ? const Center(child: Text('No students are available for posting.'))
                  : Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'DIGITAL HEALTH DEPARTMENT',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'POSTING OF SIWES STUDENTS EFFECTIVE FROM ' +
                                      PostingPeriod.formatDate(widget.periodStartDate) +
                                      ' TO ' + PostingPeriod.formatDate(_periodEndDate),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 18),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  children: [
                                    _SummaryChip(label: 'Total students', value: _preview.length.toString()),
                                    _SummaryChip(label: 'Group A', value: groupACount.toString()),
                                    _SummaryChip(label: 'Group B', value: groupBCount.toString()),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Container(
                                  color: Colors.white,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(const Color(0xFFEAF5EC)),
                                      columns: const [
                                        DataColumn(label: Text('S/N')),
                                        DataColumn(label: Text('Name')),
                                        DataColumn(label: Text('Phone Number')),
                                        DataColumn(label: Text('Group')),
                                        DataColumn(label: Text('Posting')),
                                      ],
                                      rows: [
                                        for (var i = 0; i < _preview.length; i++)
                                          DataRow(cells: [
                                            DataCell(Text((i + 1).toString())),
                                            DataCell(Text(_preview[i].student.name)),
                                            DataCell(Text(_preview[i].student.phoneNumber)),
                                            DataCell(Text(_preview[i].student.groupName)),
                                            DataCell(Text(_preview[i].unit.name)),
                                          ]),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(top: BorderSide(color: Colors.black12)),
                          ),
                          child: _confirmed
                              ? Wrap(
                                  alignment: WrapAlignment.end,
                                  spacing: 12,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: _exportExcel,
                                      icon: const Icon(Icons.table_view_outlined),
                                      label: const Text('Export Excel'),
                                    ),
                                    FilledButton.icon(
                                      onPressed: _exportingPdf ? null : _exportPdf,
                                      icon: _exportingPdf
                                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                          : const Icon(Icons.picture_as_pdf_outlined),
                                      label: const Text('Export PDF'),
                                      style: FilledButton.styleFrom(backgroundColor: Colors.green),
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Back'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: FilledButton.icon(
                                        onPressed: _confirming ? null : _confirmPosting,
                                        icon: _confirming
                                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                            : const Icon(Icons.check_circle_outline),
                                        label: const Text('Confirm Posting'),
                                        style: FilledButton.styleFrom(backgroundColor: Colors.green),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Chip(
    label: Text(label + ': ' + value),
    backgroundColor: Colors.white,
    side: const BorderSide(color: Colors.black12),
  );
}